import secrets
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.ad import Subscription
from app.models.user import SubscriptionTier, User, UserRole
from app.schemas.ad import (
    AdMobConfigResponse,
    GooglePlayPurchaseVerifyRequest,
    GooglePlayPurchaseVerifyResponse,
    SubscriptionCreateOrder,
    SubscriptionResponse,
)
from app.services.google_play import google_play_service

router = APIRouter()

# Pricing table in INR
TIER_PRICING = {
    SubscriptionTier.PRO_RESIDENT: Decimal("29.00"),
    SubscriptionTier.BUSINESS_PRO: Decimal("499.00"),
    SubscriptionTier.FREE: Decimal("0.00"),
}


@router.post(
    "/create-order",
    response_model=SubscriptionResponse,
    summary="Create Subscription Order",
    description="Generates a mock payment gateway order and updates user subscription tier status.",
)
async def create_subscription_order(
    payload: SubscriptionCreateOrder,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    base_price = TIER_PRICING.get(payload.tier, Decimal("29.00"))
    total_amount = base_price * Decimal(payload.duration_months)
    order_id = f"order_NX{secrets.token_hex(4).upper()}"

    now_utc = datetime.now(timezone.utc)
    expires_utc = now_utc + timedelta(days=30 * payload.duration_months)

    # 1. Create Subscription entry in database
    subscription = Subscription(
        user_id=current_user.id,
        tier=payload.tier,
        amount=total_amount,
        gateway_order_id=order_id,
        gateway_payment_id=f"pay_mock_{secrets.token_hex(6)}",
        starts_at=now_utc,
        expires_at=expires_utc,
        is_active=True,
    )
    db.add(subscription)

    # 2. Update user's active tier
    current_user.tier = payload.tier
    if payload.tier == SubscriptionTier.BUSINESS_PRO:
        current_user.role = UserRole.BUSINESS
        current_user.is_verified = True

    await db.commit()
    await db.refresh(subscription)

    return SubscriptionResponse(
        order_id=order_id,
        amount_inr=float(total_amount),
        currency="INR",
        tier=payload.tier.value if hasattr(payload.tier, "value") else str(payload.tier),
        starts_at=subscription.starts_at,
        expires_at=subscription.expires_at,
    )


@router.post(
    "/verify-purchase",
    response_model=GooglePlayPurchaseVerifyResponse,
    summary="Verify Google Play In-App Purchase / Subscription",
    description="Validates Google Play billing token and activates verified merchant status or user subscription tier.",
)
async def verify_google_play_purchase(
    payload: GooglePlayPurchaseVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # 1. Verify receipt with Google Play Billing Service
    result = await google_play_service.verify_purchase(
        purchase_token=payload.purchase_token,
        product_id=payload.product_id,
        package_name=payload.package_name,
    )

    if not result.is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google Play purchase receipt verification failed or subscription is inactive",
        )

    # 2. Activate Tier and Role
    current_user.tier = result.tier
    is_merchant = False

    if result.tier == SubscriptionTier.BUSINESS_PRO:
        current_user.role = UserRole.BUSINESS
        current_user.is_verified = True
        is_merchant = True

    # 3. Record in Subscriptions Table
    amount = TIER_PRICING.get(result.tier, Decimal("29.00"))
    subscription = Subscription(
        user_id=current_user.id,
        tier=result.tier,
        amount=amount,
        gateway_order_id=result.order_id or f"GPA.{secrets.token_hex(4).upper()}",
        gateway_payment_id=f"gp_token_{payload.purchase_token[:20]}",
        starts_at=result.starts_at,
        expires_at=result.expires_at,
        is_active=True,
    )
    db.add(subscription)

    await db.commit()
    await db.refresh(subscription)

    return GooglePlayPurchaseVerifyResponse(
        success=True,
        message="Google Play purchase verified successfully. Subscription activated.",
        tier=result.tier.value if hasattr(result.tier, "value") else str(result.tier),
        order_id=result.order_id,
        is_active=True,
        is_verified_merchant=is_merchant,
        starts_at=result.starts_at,
        expires_at=result.expires_at,
    )


@router.get(
    "/admob-config",
    response_model=AdMobConfigResponse,
    summary="Get AdMob Ad Unit Configuration",
    description="Returns AdMob App and Ad Unit IDs for hyperlocal client-side banner/native ad placements.",
)
async def get_admob_config():
    return AdMobConfigResponse(
        app_id=settings.ADMOB_APP_ID,
        banner_ad_unit_id=settings.ADMOB_BANNER_AD_UNIT_ID,
        native_ad_unit_id=settings.ADMOB_NATIVE_AD_UNIT_ID,
    )


@router.get(
    "/tiers",
    summary="List Subscription Tiers",
)
async def get_subscription_tiers():
    return {
        "tiers": [
            {
                "tier": SubscriptionTier.FREE.value,
                "price_monthly_inr": 0.00,
                "features": ["Hyperlocal radius feed", "Civic SOS broadcasts", "Local comments & upvotes"],
            },
            {
                "tier": SubscriptionTier.PRO_RESIDENT.value,
                "price_monthly_inr": 29.00,
                "features": ["100% Ad-free feed", "Verified resident badge", "Priority SOS notifications"],
            },
            {
                "tier": SubscriptionTier.BUSINESS_PRO.value,
                "price_monthly_inr": 499.00,
                "features": ["Native sponsor ad injection", "WhatsApp direct lead CTA", "Local search priority"],
            },
        ]
    }
