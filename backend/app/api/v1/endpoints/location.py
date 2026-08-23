from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import UserLocationResponse, UserLocationUpdate
from app.services.geo_service import GeoService

router = APIRouter()


@router.put(
    "/sync",
    response_model=UserLocationResponse,
    summary="Update Resident Location Ping",
    description="Synchronizes the mobile device GPS coordinates and preferred geofence radius.",
)
async def sync_location(
    payload: UserLocationUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_loc = await GeoService.sync_user_location(
        db=db,
        user_id=current_user.id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        pincode=payload.pincode,
        preferred_radius_meters=payload.preferred_radius_meters,
    )

    return UserLocationResponse(
        success=True,
        active_radius_meters=user_loc.preferred_radius_meters,
        zone_name=f"Zone Pincode {user_loc.pincode}",
    )
