import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.models.user import SubscriptionTier, User, UserLocation, UserRole
from app.schemas.user import UserProfileResponse, UserProfileSyncRequest

router = APIRouter()


@router.post(
    "/sync",
    response_model=UserProfileResponse,
    summary="Sync Clerk Resident Profile to Supabase",
    description="Upserts user profile metadata into Supabase with automatic anonymous handle generation.",
)
async def sync_user_profile(
    payload: UserProfileSyncRequest,
    current_user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    user = current_user

    # If not resolved via bearer token dependency, lookup or create by payload identifiers
    if not user:
        clerk_id = payload.clerk_user_id
        email = payload.email.lower().strip() if payload.email else None

        lookup_conditions = []
        if clerk_id:
            lookup_conditions.append(User.clerk_user_id == clerk_id)
        if email:
            lookup_conditions.append(User.email == email)

        if lookup_conditions:
            stmt = select(User).where(or_(*lookup_conditions))
            result = await db.execute(stmt)
            user = result.scalar_one_or_none()

        if not user:
            # Auto-provision new profile record in Supabase
            alias = payload.alias_name or f"Resident_{secrets.token_hex(2)}"
            user = User(
                id=uuid.uuid4(),
                clerk_user_id=clerk_id,
                email=email,
                alias_name=alias,
                avatar_url=payload.avatar_url,
                role=UserRole.RESIDENT,
                tier=SubscriptionTier.FREE,
                is_verified=True,
                is_active=True,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unable to resolve or provision user profile from credentials.",
        )

    # Sync and update any updated metadata
    updated = False
    if payload.alias_name and payload.alias_name != user.alias_name:
        user.alias_name = payload.alias_name
        updated = True
    elif not user.alias_name:
        user.alias_name = f"Resident_{secrets.token_hex(2)}"
        updated = True

    if payload.email and not user.email:
        user.email = payload.email.lower().strip()
        updated = True

    if payload.avatar_url and payload.avatar_url != user.avatar_url:
        user.avatar_url = payload.avatar_url
        updated = True

    if payload.clerk_user_id and not user.clerk_user_id:
        user.clerk_user_id = payload.clerk_user_id
        updated = True

    if updated:
        await db.commit()
        await db.refresh(user)

    # Query location radius if existing
    loc_stmt = select(UserLocation).where(UserLocation.user_id == user.id)
    loc_res = await db.execute(loc_stmt)
    loc = loc_res.scalar_one_or_none()
    radius_meters = (
        getattr(loc, "preferred_radius_meters", 1500)
        if loc and hasattr(loc, "preferred_radius_meters")
        else 1500
    )
    radius_km = radius_meters / 1000.0

    return UserProfileResponse(
        id=user.id,
        clerk_user_id=user.clerk_user_id,
        alias=user.alias_name,
        email=user.email,
        avatar_url=user.avatar_url,
        radius_km=radius_km,
        tier=user.tier.value if hasattr(user.tier, "value") else str(user.tier),
        is_verified=user.is_verified,
        created_at=user.created_at,
    )


@router.get(
    "/me",
    response_model=UserProfileResponse,
    summary="Get Current Resident Profile",
    description="Returns verified resident profile and radius parameters from Supabase.",
)
async def get_user_profile_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    loc_stmt = select(UserLocation).where(UserLocation.user_id == current_user.id)
    loc_res = await db.execute(loc_stmt)
    loc = loc_res.scalar_one_or_none()
    radius_meters = (
        getattr(loc, "preferred_radius_meters", 1500)
        if loc and hasattr(loc, "preferred_radius_meters")
        else 1500
    )
    radius_km = radius_meters / 1000.0

    return UserProfileResponse(
        id=current_user.id,
        clerk_user_id=current_user.clerk_user_id,
        alias=current_user.alias_name,
        email=current_user.email,
        avatar_url=current_user.avatar_url,
        radius_km=radius_km,
        tier=(
            current_user.tier.value
            if hasattr(current_user.tier, "value")
            else str(current_user.tier)
        ),
        is_verified=current_user.is_verified,
        created_at=current_user.created_at,
    )
