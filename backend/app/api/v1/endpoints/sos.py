import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.core.redis import check_rate_limit, get_redis
from app.models.user import User
from app.schemas.sos import (
    ActiveSOSResponse,
    SOSBroadcastResponse,
    SOSCreate,
    SOSEventDetail,
    SOSResolveResponse,
)
from app.services.alert_service import AlertService

router = APIRouter()


@router.post(
    "/broadcast",
    response_model=SOSBroadcastResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Trigger Instant Civic SOS Emergency Broadcast",
    description=(
        "Publishes an emergency alert to all verified residents within 1.5 km via "
        "Redis PubSub and PostGIS spatial reach math with a 5-minute cooldown."
    ),
)
@router.post(
    "/trigger",
    response_model=SOSBroadcastResponse,
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False,
)
async def broadcast_sos(
    payload: SOSCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis | None = Depends(get_redis),
):
    # 1. Enforce 5-minute cooldown (1 active SOS per user / 5 mins)
    cooldown_key = f"ratelimit:sos_cooldown:{current_user.id}"
    if redis:
        allowed = await check_rate_limit(
            redis, cooldown_key, max_requests=1, window_seconds=300
        )
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="An active SOS was recently broadcasted. 5-minute cooldown in effect.",
            )

    # 2. Trigger SOS creation, geographic recipient lookup, and PubSub dispatch
    emergency_cat = payload.category or payload.emergency_type or "security"
    response = await AlertService.create_and_dispatch_sos(
        db=db,
        redis=redis,
        user_id=current_user.id,
        emergency_type=emergency_cat,
        description=payload.description,
        latitude=payload.latitude,
        longitude=payload.longitude,
        broadcast_radius_meters=1500,
    )

    return response


@router.get(
    "/active",
    response_model=ActiveSOSResponse,
    summary="Get User Current Active SOS Alert",
    description="Returns the resident's currently active unresolved emergency state (if any).",
)
async def get_user_active_sos(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await AlertService.fetch_user_active_sos(db=db, user_id=current_user.id)


@router.get(
    "/nearby",
    response_model=list[SOSEventDetail],
    summary="Fetch Active Radius Emergencies",
    description="Returns all unresolved SOS emergency alerts within the resident's neighborhood radius.",
)
async def get_nearby_active_sos(
    lat: float = Query(26.7922, description="Latitude"),
    lng: float = Query(82.1998, description="Longitude"),
    radius_meters: int = Query(3000, ge=500, le=10000, description="Radius in meters"),
    db: AsyncSession = Depends(get_db),
):
    events = await AlertService.fetch_active_sos(
        db=db,
        latitude=lat,
        longitude=lng,
        radius_meters=radius_meters,
    )
    return events


@router.post(
    "/{event_id}/resolve",
    response_model=SOSResolveResponse,
    summary="Cancel / Resolve Active SOS Emergency",
    description="Marks an active emergency as resolved and notifies responders.",
)
async def resolve_sos(
    event_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await AlertService.resolve_sos_event(
        db=db,
        event_id=event_id,
        current_user=current_user,
    )
