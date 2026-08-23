import logging
import time
from typing import Any

import jwt
from jwt import PyJWKClient

from app.core.config import settings

logger = logging.getLogger(__name__)

# Global PyJWKClient instance for Clerk JWKS token verification with key caching
_jwks_client: PyJWKClient | None = None


def get_jwks_client() -> PyJWKClient | None:
    """Retrieve or initialize the PyJWKClient for Clerk JWKS validation."""
    global _jwks_client
    if _jwks_client is None:
        jwks_url = settings.CLERK_JWKS_URL
        if not jwks_url and settings.CLERK_ISSUER_URL:
            jwks_url = f"{settings.CLERK_ISSUER_URL.rstrip('/')}/.well-known/jwks.json"

        if jwks_url:
            try:
                _jwks_client = PyJWKClient(jwks_url, cache_jwk_set=True, lifespan=3600)
            except Exception as e:
                logger.warning(
                    f"Failed to initialize PyJWKClient with URL {jwks_url}: {e}"
                )
                _jwks_client = None
    return _jwks_client


def decode_clerk_jwt(token: str) -> dict[str, Any]:
    """Decode and validate a Clerk-issued JWT token.

    Attempts verification via:
    1. Clerk JWKS public key endpoint (RS256)
    2. Clerk secret key (if symmetric or provided)
    3. Unverified claims extraction fallback in non-production/test environments.

    Raises:
        jwt.PyJWTError: If token validation fails.
    """
    jwks_client = get_jwks_client()

    # 1. Try JWKS verification if client is available
    if jwks_client:
        try:
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            options = {"verify_aud": False}
            if not settings.CLERK_ISSUER_URL:
                options["verify_iss"] = False

            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256", "ES256", "RS512"],
                issuer=settings.CLERK_ISSUER_URL if settings.CLERK_ISSUER_URL else None,
                options=options,
            )
            return payload
        except Exception as e:
            logger.debug(f"JWKS verification failed, trying fallback: {e}")

    # 2. Try Clerk Secret Key if configured
    if settings.CLERK_SECRET_KEY:
        try:
            payload = jwt.decode(
                token,
                settings.CLERK_SECRET_KEY,
                algorithms=["HS256", "HS512", "RS256"],
                options={
                    "verify_signature": True,
                    "verify_aud": False,
                    "verify_iss": False,
                },
            )
            return payload
        except Exception:
            pass

    # 3. Development / Test environment unverified decode fallback for mock Clerk tokens
    if settings.ENVIRONMENT in ("development", "test"):
        try:
            unverified_payload = jwt.decode(token, options={"verify_signature": False})
            # Verify basic expiration even in unverified mode
            if "exp" in unverified_payload:
                if unverified_payload["exp"] < time.time():
                    raise jwt.ExpiredSignatureError("Clerk token has expired")
            return unverified_payload
        except jwt.ExpiredSignatureError:
            raise
        except Exception as e:
            logger.debug(f"Unverified token decode failed: {e}")

    raise jwt.InvalidTokenError(
        "Could not validate Clerk JWT token with JWKS or secret key"
    )


def extract_clerk_user_claims(payload: dict[str, Any]) -> dict[str, Any]:
    """Extract standard and custom user identity claims from Clerk payload.

    Extracts:
    - sub (Clerk User ID)
    - phone_number (primary phone)
    - email (primary email)
    - alias_name / name
    """
    sub = payload.get("sub", "")

    # Extract phone number from potential claim keys
    phone_number = (
        payload.get("phone_number")
        or payload.get("phone")
        or payload.get("primary_phone_number")
        or payload.get("mobile")
    )

    # If phone numbers are structured as a list
    if (
        not phone_number
        and isinstance(payload.get("phone_numbers"), list)
        and payload["phone_numbers"]
    ):
        first_phone = payload["phone_numbers"][0]
        if isinstance(first_phone, dict):
            phone_number = first_phone.get("phone_number")
        elif isinstance(first_phone, str):
            phone_number = first_phone

    # Extract email from potential claim keys
    email = (
        payload.get("email")
        or payload.get("email_address")
        or payload.get("primary_email_address")
    )
    if (
        not email
        and isinstance(payload.get("email_addresses"), list)
        and payload["email_addresses"]
    ):
        first_email = payload["email_addresses"][0]
        if isinstance(first_email, dict):
            email = first_email.get("email_address")
        elif isinstance(first_email, str):
            email = first_email

    # Extract name / alias
    alias_name = (
        payload.get("alias_name")
        or payload.get("username")
        or payload.get("first_name")
        or payload.get("name")
    )
    if not alias_name and sub:
        alias_name = f"Resident_{sub[-4:]}"

    # Fallback phone generation if sub is available but phone is not in token claims
    if not phone_number and sub:
        numeric_suffix = "".join(c for c in sub if c.isdigit())
        if len(numeric_suffix) >= 10:
            phone_number = f"+91{numeric_suffix[:10]}"
        else:
            import hashlib

            h = int(hashlib.md5(sub.encode("utf-8")).hexdigest(), 16)
            phone_number = f"+91{h % 9000000000 + 1000000000!s}"

    return {
        "sub": sub,
        "phone_number": phone_number,
        "email": email,
        "alias_name": alias_name,
        "raw_payload": payload,
    }
