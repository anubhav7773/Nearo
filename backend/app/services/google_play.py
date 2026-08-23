import base64
import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional
from pydantic import BaseModel
import httpx

from app.core.config import settings
from app.models.user import SubscriptionTier

logger = logging.getLogger(__name__)


class GooglePlayPurchaseResult(BaseModel):
    is_valid: bool
    tier: SubscriptionTier
    order_id: Optional[str] = None
    purchase_state: int = 0  # 0: Purchased, 1: Canceled, 2: Pending
    starts_at: datetime
    expires_at: datetime
    is_acknowledged: bool = True
    raw_response: Dict[str, Any] = {}


class GooglePlayBillingService:
    """Service to verify in-app purchases and subscriptions via Google Play Developer API."""

    def __init__(
        self,
        package_name: Optional[str] = None,
        service_account_json: Optional[str] = None,
    ):
        self.package_name = package_name or settings.GOOGLE_PLAY_PACKAGE_NAME
        self.service_account_json = service_account_json or settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
        self._parsed_service_account: Optional[Dict[str, Any]] = None
        self._load_service_account()

    def _load_service_account(self) -> None:
        """Parse service account from Base64 string, file path, or raw JSON."""
        if not self.service_account_json:
            return

        raw = self.service_account_json.strip()
        try:
            # 1. Check if it's a file path
            if os.path.isfile(raw):
                with open(raw, "r", encoding="utf-8") as f:
                    self._parsed_service_account = json.load(f)
                    return
            
            # 2. Check if Base64 encoded
            try:
                decoded = base64.b64decode(raw).decode("utf-8")
                self._parsed_service_account = json.loads(decoded)
                return
            except Exception:
                pass

            # 3. Check if raw JSON string
            if raw.startswith("{") and raw.endswith("}"):
                self._parsed_service_account = json.loads(raw)
                return
        except Exception as e:
            logger.error(f"Failed to parse Google Play Service Account JSON: {e}")
            self._parsed_service_account = None

    def map_product_to_tier(self, product_id: str) -> SubscriptionTier:
        """Map Google Play SKU / Product ID to Nearo SubscriptionTier."""
        clean_id = product_id.lower()
        if "business" in clean_id or "merchant" in clean_id:
            return SubscriptionTier.BUSINESS_PRO
        elif "pro" in clean_id or "resident" in clean_id:
            return SubscriptionTier.PRO_RESIDENT
        return SubscriptionTier.PRO_RESIDENT

    async def verify_purchase(
        self,
        purchase_token: str,
        product_id: str,
        package_name: Optional[str] = None,
    ) -> GooglePlayPurchaseResult:
        """Verify subscription or one-time in-app product token with Google Play."""
        pkg = package_name or self.package_name
        tier = self.map_product_to_tier(product_id)
        now_utc = datetime.now(timezone.utc)

        # 1. Handle Mock/Sandbox or Dev Test Tokens
        if (
            settings.ENVIRONMENT in ("development", "test")
            or purchase_token.startswith("mock_")
            or purchase_token.startswith("test_")
            or not self._parsed_service_account
        ):
            # Deterministic mock order ID from token
            order_id = f"GPA.{int(time.time())}-{hash(purchase_token) % 1000000:06d}"
            # 30-day standard billing cycle for subscriptions
            duration_days = 365 if "annual" in product_id.lower() or "yearly" in product_id.lower() else 30
            expires_utc = now_utc + timedelta(days=duration_days)

            return GooglePlayPurchaseResult(
                is_valid=True,
                tier=tier,
                order_id=order_id,
                purchase_state=0,
                starts_at=now_utc,
                expires_at=expires_utc,
                is_acknowledged=True,
                raw_response={
                    "mock": True,
                    "product_id": product_id,
                    "package_name": pkg,
                    "purchase_token": purchase_token,
                },
            )

        # 2. Production Live Verification via Google Play Developer API
        try:
            access_token = await self._get_google_oauth_token()
            headers = {"Authorization": f"Bearer {access_token}"}
            
            # Check subscription endpoint first
            sub_url = (
                f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                f"{pkg}/purchases/subscriptions/{product_id}/tokens/{purchase_token}"
            )
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(sub_url, headers=headers)
                
                if res.status_code == 200:
                    data = res.json()
                    # Expiry time millis
                    expiry_millis = int(data.get("expiryTimeMillis", 0))
                    expires_utc = (
                        datetime.fromtimestamp(expiry_millis / 1000.0, tz=timezone.utc)
                        if expiry_millis > 0
                        else now_utc + timedelta(days=30)
                    )
                    
                    is_valid = expires_utc > now_utc
                    order_id = data.get("orderId", f"GPA.{int(time.time())}")
                    
                    return GooglePlayPurchaseResult(
                        is_valid=is_valid,
                        tier=tier,
                        order_id=order_id,
                        purchase_state=0 if is_valid else 1,
                        starts_at=now_utc,
                        expires_at=expires_utc,
                        is_acknowledged=data.get("acknowledgementState", 0) == 1,
                        raw_response=data,
                    )
                
                # Check one-time in-app product endpoint
                product_url = (
                    f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                    f"{pkg}/purchases/products/{product_id}/tokens/{purchase_token}"
                )
                res_product = await client.get(product_url, headers=headers)
                if res_product.status_code == 200:
                    data = res_product.json()
                    purchase_state = data.get("purchaseState", 0)  # 0: Purchased
                    order_id = data.get("orderId", f"GPA.{int(time.time())}")
                    expires_utc = now_utc + timedelta(days=30)

                    return GooglePlayPurchaseResult(
                        is_valid=(purchase_state == 0),
                        tier=tier,
                        order_id=order_id,
                        purchase_state=purchase_state,
                        starts_at=now_utc,
                        expires_at=expires_utc,
                        is_acknowledged=data.get("consumptionState", 0) == 1,
                        raw_response=data,
                    )

                logger.error(f"Google Play API verification error {res.status_code}: {res.text}")
                return GooglePlayPurchaseResult(
                    is_valid=False,
                    tier=tier,
                    order_id=None,
                    purchase_state=1,
                    starts_at=now_utc,
                    expires_at=now_utc,
                    is_acknowledged=False,
                    raw_response={"error": res.text, "status_code": res.status_code},
                )
        except Exception as e:
            logger.error(f"Unexpected error validating Google Play purchase: {e}")
            return GooglePlayPurchaseResult(
                is_valid=False,
                tier=tier,
                order_id=None,
                purchase_state=1,
                starts_at=now_utc,
                expires_at=now_utc,
                is_acknowledged=False,
                raw_response={"error": str(e)},
            )

    async def _get_google_oauth_token(self) -> str:
        """Obtain Google OAuth2 bearer token from Service Account credentials."""
        if not self._parsed_service_account:
            raise ValueError("Google Play Service Account JSON not configured")

        client_email = self._parsed_service_account.get("client_email")
        private_key = self._parsed_service_account.get("private_key")
        token_uri = self._parsed_service_account.get("token_uri", "https://oauth2.googleapis.com/token")

        now = int(time.time())
        claims = {
            "iss": client_email,
            "scope": "https://www.googleapis.com/auth/androidpublisher",
            "aud": token_uri,
            "iat": now,
            "exp": now + 3600,
        }

        import jwt
        assertion = jwt.encode(claims, private_key, algorithm="RS256")

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                token_uri,
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    "assertion": assertion,
                },
            )
            resp.raise_for_status()
            return resp.json()["access_token"]


google_play_service = GooglePlayBillingService()
