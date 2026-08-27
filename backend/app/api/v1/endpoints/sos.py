import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
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
    "",
    response_model=SOSBroadcastResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Trigger Instant Civic SOS Emergency Broadcast",
    description="Publishes an emergency alert to verified residents within geographic radius.",
)
@router.post(
    "/broadcast",
    response_model=SOSBroadcastResponse,
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False,
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
    radius = int(payload.radius_meters or payload.broadcast_radius_meters or 1500)

    response = await AlertService.create_and_dispatch_sos(
        db=db,
        redis=redis,
        user_id=current_user.id,
        emergency_type=emergency_cat,
        description=payload.description,
        latitude=float(payload.latitude or payload.lat or 26.7922),
        longitude=float(payload.longitude or payload.lng or 82.1998),
        broadcast_radius_meters=radius,
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
    lat: float | None = Query(None, description="Latitude"),
    lng: float | None = Query(None, description="Longitude"),
    latitude: float | None = Query(None, description="Latitude alias"),
    longitude: float | None = Query(None, description="Longitude alias"),
    radius_meters: int = Query(3000, ge=500, le=10000, description="Radius in meters"),
    db: AsyncSession = Depends(get_db),
):
    target_lat = lat if lat is not None else (latitude if latitude is not None else 26.7922)
    target_lng = lng if lng is not None else (longitude if longitude is not None else 82.1998)
    events = await AlertService.fetch_active_sos(
        db=db,
        latitude=target_lat,
        longitude=target_lng,
        radius_meters=radius_meters,
    )
    return events


@router.get(
    "/{event_id}",
    response_model=SOSEventDetail,
    summary="Get SOS Emergency Details by ID",
    description="Fetches specific active or past SOS event details.",
)
async def get_sos_event_details(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    return await AlertService.fetch_sos_by_id(db=db, event_id=event_id)


@router.post(
    "/{event_id}/resolve",
    response_model=SOSResolveResponse,
    summary="Cancel / Resolve Active SOS Emergency",
    description="Marks an active emergency as resolved and notifies responders.",
)
@router.post(
    "/{event_id}/cancel",
    response_model=SOSResolveResponse,
    summary="Cancel Active SOS Emergency (Alias)",
    description="Marks an active emergency as resolved.",
    include_in_schema=False,
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
