import logging
import secrets
import uuid

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from redis.asyncio import Redis
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import decode_clerk_jwt, extract_clerk_user_claims
from app.core.config import settings
from app.core.database import get_db
from app.core.firebase import verify_firebase_token
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
    """Validate bearer access token (Firebase Admin SDK, Internal JWT, or Clerk) and return/provision User."""
    if not auth or not auth.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth.credentials
    user: User | None = None

    # -------------------------------------------------------------------------
    # 1. Primary: Verify Firebase ID Token via Firebase Admin SDK
    # -------------------------------------------------------------------------
    try:
        firebase_payload = verify_firebase_token(token)
        uid = firebase_payload.get("uid")
        if uid:
            email = firebase_payload.get("email")
            phone = firebase_payload.get("phone_number")
            name = firebase_payload.get("name")
            avatar_url = firebase_payload.get("avatar_url")
            alias = name or f"Resident_{uid[-4:] if len(uid) >= 4 else secrets.token_hex(2)}"

            # Lookup by firebase_uid, email, or phone
            lookup_filters = [User.firebase_uid == uid]
            if email:
                lookup_filters.append(User.email == email.lower().strip())
            if phone:
                lookup_filters.append(User.phone_number == phone.strip())

            stmt = select(User).where(or_(*lookup_filters))
            result = await db.execute(stmt)
            user = result.scalar_one_or_none()

            if not user:
                # Auto-provision new resident record in Supabase
                user = User(
                    id=uuid.uuid4(),
                    firebase_uid=uid,
                    email=email.lower().strip() if email else None,
                    phone_number=phone.strip() if phone else None,
                    alias_name=alias,
                    avatar_url=avatar_url,
                    auth_provider="firebase",
                    role=UserRole.RESIDENT,
                    tier=SubscriptionTier.FREE,
                    is_verified=True,
                    is_active=True,
                )
                db.add(user)
                await db.commit()
                await db.refresh(user)
            else:
                # Update existing user record with Firebase UID / metadata if needed
                updated = False
                if not user.firebase_uid:
                    user.firebase_uid = uid
                    updated = True
                if email and not user.email:
                    user.email = email.lower().strip()
                    updated = True
                if phone and not user.phone_number:
                    user.phone_number = phone.strip()
                    updated = True
                if not user.is_verified:
                    user.is_verified = True
                    updated = True
                if updated:
                    await db.commit()
                    await db.refresh(user)
    except Exception as exc:
        logger.debug("Firebase token verification bypassed: %s", str(exc))

    # -------------------------------------------------------------------------
    # 2. Secondary: Internal Nearo HMAC JWT Validation
    # -------------------------------------------------------------------------
    if not user:
        try:
            payload = decode_token(token)
            user_id_str: str | None = payload.get("sub")
            token_type: str | None = payload.get("type")
            jti: str | None = payload.get("jti")

            if user_id_str and token_type == "access":
                # Check token blocklist in Redis if available
                if redis and jti:
                    try:
                        is_blocked = await redis.get(f"jwt_blocklist:{jti}")
                        if is_blocked:
                            raise HTTPException(
                                status_code=status.HTTP_401_UNAUTHORIZED,
                                detail="Token has been revoked",
                            )
                    except Exception:
                        pass

                try:
                    user_id = uuid.UUID(user_id_str)
                    result = await db.execute(select(User).where(User.id == user_id))
                    user = result.scalar_one_or_none()
                except ValueError:
                    pass
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication token has expired",
            )
        except Exception:
            pass

    # -------------------------------------------------------------------------
    # 3. Tertiary: Legacy Clerk Token Validation Fallback
    # -------------------------------------------------------------------------
    if not user and settings.CLERK_PUBLISHABLE_KEY:
        try:
            clerk_payload = decode_clerk_jwt(token)
            clerk_claims = extract_clerk_user_claims(clerk_payload)
            if clerk_claims:
                clerk_id = clerk_claims.get("sub")
                email = clerk_claims.get("email")
                phone_number = clerk_claims.get("phone_number")
                alias_name = (
                    clerk_claims.get("alias_name")
                    or (f"Resident_{clerk_id[-4:]}" if clerk_id else f"Resident_{secrets.token_hex(2)}")
                )

                lookup_filters = []
                if clerk_id:
                    lookup_filters.append(User.clerk_user_id == clerk_id)
                if email:
                    lookup_filters.append(User.email == email)
                if phone_number:
                    lookup_filters.append(User.phone_number == phone_number)

                if lookup_filters:
                    stmt = select(User).where(or_(*lookup_filters))
                    result = await db.execute(stmt)
                    user = result.scalar_one_or_none()

                if not user:
                    user = User(
                        id=uuid.uuid4(),
                        clerk_user_id=clerk_id,
                        email=email,
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
        except Exception:
            pass

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials or user not found",
            headers={"WWW-Authenticate": "Bearer"},
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
