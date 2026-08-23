import logging
import secrets
import uuid

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from redis.asyncio import Redis
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.firebase import init_firebase, verify_firebase_token
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
    """Validate bearer access token (Firebase ID Token or Internal JWT) and return/provision User."""
    if not auth or not auth.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth.credentials.strip()
    if token.lower().startswith("bearer "):
        token = token[7:].strip()

    # -------------------------------------------------------------------------
    # 1. Primary: Verify Firebase ID Token via Firebase Admin SDK
    # -------------------------------------------------------------------------
    firebase_payload = None
    try:
        init_firebase()
        firebase_payload = verify_firebase_token(token)
    except Exception as exc:
        logger.debug("Firebase token verification bypassed/failed: %s", str(exc))

    if firebase_payload and firebase_payload.get("uid"):
        uid = firebase_payload.get("uid")
        email = (firebase_payload.get("email") or "").lower().strip() or None
        phone = (firebase_payload.get("phone_number") or "").strip() or None
        name = firebase_payload.get("name")
        avatar_url = firebase_payload.get("avatar_url") or firebase_payload.get("picture")
        alias = (
            name
            or (email.split("@")[0] if email else None)
            or f"Resident_{uid[-4:] if len(uid) >= 4 else secrets.token_hex(2)}"
        )

        try:
            lookup_filters = [User.firebase_uid == uid]
            if email:
                lookup_filters.append(User.email == email)
            if phone:
                lookup_filters.append(User.phone_number == phone)

            stmt = select(User).where(or_(*lookup_filters))
            result = await db.execute(stmt)

            user = None
            if hasattr(result, "scalar_one_or_none"):
                try:
                    user = result.scalar_one_or_none()
                except Exception:
                    pass
            if user is None and hasattr(result, "scalars"):
                try:
                    user = result.scalars().first()
                except Exception:
                    pass

            if not user or not isinstance(user, User):
                # Auto-provision new resident record in Supabase
                user = User(
                    id=uuid.uuid4(),
                    firebase_uid=uid,
                    email=email,
                    phone_number=phone,
                    alias_name=alias,
                    avatar_url=avatar_url,
                    auth_provider="google" if email else "phone",
                    role=UserRole.RESIDENT,
                    tier=SubscriptionTier.FREE,
                    is_verified=True,
                    is_active=True,
                )
                db.add(user)
                await db.commit()
                await db.refresh(user)
            else:
                # Update existing user record with Firebase UID / metadata if missing
                updated = False
                if not user.firebase_uid:
                    user.firebase_uid = uid
                    updated = True
                if email and not user.email:
                    user.email = email
                    updated = True
                if phone and not user.phone_number:
                    user.phone_number = phone
                    updated = True
                if not user.is_verified:
                    user.is_verified = True
                    updated = True
                if updated:
                    await db.commit()
                    await db.refresh(user)

            if not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Inactive resident account",
                )
            return user
        except HTTPException:
            raise
        except Exception as exc:
            await db.rollback()
            logger.error("Supabase user provisioning error: %s", str(exc))
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Database user provisioning error: {str(exc)}",
            )

    # -------------------------------------------------------------------------
    # 2. Secondary: Internal Nearo HMAC JWT Validation (Testing & Local Tokens)
    # -------------------------------------------------------------------------
    try:
        payload = decode_token(token)
        user_id_str: str | None = payload.get("sub")
        token_type: str | None = payload.get("type")
        jti: str | None = payload.get("jti")

        if user_id_str and token_type == "access":
            if redis and jti:
                try:
                    is_blocked = await redis.get(f"jwt_blocklist:{jti}")
                    if is_blocked:
                        raise HTTPException(
                            status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Token has been revoked",
                        )
                except HTTPException:
                    raise
                except Exception:
                    pass

            try:
                user_id = uuid.UUID(user_id_str)
                result = await db.execute(select(User).where(User.id == user_id))
                user = None
                if hasattr(result, "scalar_one_or_none"):
                    try:
                        user = result.scalar_one_or_none()
                    except Exception:
                        pass
                if user is None and hasattr(result, "scalars"):
                    try:
                        user = result.scalars().first()
                    except Exception:
                        pass

                if not user or not isinstance(user, User):
                    # Auto-provision user for internal/test token
                    user = User(
                        id=user_id,
                        alias_name=f"Resident_{user_id_str[:4]}",
                        auth_provider="internal",
                        role=UserRole.RESIDENT,
                        tier=SubscriptionTier.FREE,
                        is_verified=True,
                        is_active=True,
                    )
                    db.add(user)
                    await db.commit()
                    await db.refresh(user)

                if user:
                    if not user.is_active:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="Inactive resident account",
                        )
                    return user
            except ValueError:
                pass
            except Exception as e:
                await db.rollback()
                logger.error("DB lookup error for internal token: %s", str(e))
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired",
        )
    except HTTPException:
        raise
    except Exception:
        pass

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials or user not found",
        headers={"WWW-Authenticate": "Bearer"},
    )


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
    except Exception:
        return None
