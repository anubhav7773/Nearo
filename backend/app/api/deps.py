import logging
import uuid

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import decode_clerk_jwt, extract_clerk_user_claims
from app.core.config import settings
from app.core.database import get_db
from app.core.redis import get_redis
from app.core.security import decode_token
from app.models.user import SubscriptionTier, User, UserRole

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False)


async def get_current_user(
    auth: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
    redis: Redis | None = Depends(get_redis),
) -> User:
    """Validate bearer access token (Clerk JWKS or Internal JWT) and return/provision User model."""
    if not auth or not auth.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth.credentials
    user: User | None = None

    # Step 1: Attempt Clerk JWT validation first (or check if Clerk token)
    is_clerk_token = False
    clerk_claims = None

    try:
        # Check header/payload structure to see if it's a Clerk token or internal token
        unverified_payload = jwt.decode(token, options={"verify_signature": False})
        iss = unverified_payload.get("iss", "")
        sub = str(unverified_payload.get("sub", ""))
        has_clerk_publishable = bool(settings.CLERK_PUBLISHABLE_KEY)
        is_missing_token_type = not unverified_payload.get("type")

        if (
            "clerk" in iss
            or sub.startswith("user_")
            or (is_missing_token_type and has_clerk_publishable)
        ):
            is_clerk_token = True
            payload = decode_clerk_jwt(token)
            clerk_claims = extract_clerk_user_claims(payload)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired",
        )
    except Exception as e:
        logger.debug(f"Clerk decode check passed through to internal JWT: {e}")

    # Step 2: Handle Clerk User Provisioning / Resolution
    if is_clerk_token and clerk_claims:
        phone_number = clerk_claims.get("phone_number")
        alias_name = (
            clerk_claims.get("alias_name") or f"Resident_{clerk_claims['sub'][-4:]}"
        )

        if not phone_number:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Clerk user profile must include a valid mobile phone number",
            )

        # Lookup existing user by phone number
        stmt = select(User).where(User.phone_number == phone_number)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if not user:
            # Auto-provision new resident record in Supabase
            user = User(
                phone_number=phone_number,
                alias_name=alias_name,
                role=UserRole.RESIDENT,
                tier=SubscriptionTier.FREE,
                is_verified=True,
                is_active=True,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
        else:
            # Update verification status
            if not user.is_verified:
                user.is_verified = True
                await db.commit()
                await db.refresh(user)

    # Step 3: Handle Internal JWT validation fallback
    if not user:
        try:
            payload = decode_token(token)
            user_id_str: str | None = payload.get("sub")
            token_type: str | None = payload.get("type")
            jti: str | None = payload.get("jti")

            if not user_id_str or token_type != "access":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token claims or token type",
                )

            # Check token blocklist in Redis if available
            if redis and jti:
                is_blocked = await redis.get(f"jwt_blocklist:{jti}")
                if is_blocked:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Token has been revoked",
                    )

            user_id = uuid.UUID(user_id_str)
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication token has expired",
            )
        except (jwt.PyJWTError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User associated with token not found",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive resident account",
        )

    return user


async def get_current_user_optional(
    auth: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
    redis: Redis | None = Depends(get_redis),
) -> User | None:
    """Optionally resolve the current User if bearer token is provided."""
    if not auth or not auth.credentials:
        return None
    try:
        return await get_current_user(auth=auth, db=db, redis=redis)
    except HTTPException:
        return None
