from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.schemas.ad import NativeAdResponse
from app.services.ad_engine import AdEngine

router = APIRouter()


@router.get(
    "/nearby",
    response_model=list[NativeAdResponse],
    summary="Get Nearby Hyperlocal Ads",
)
async def get_nearby_ads(
    lat: float = Query(26.7922, description="Latitude"),
    lng: float = Query(82.1998, description="Longitude"),
    limit: int = Query(5, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
):
    ads = await AdEngine.fetch_nearby_active_ads(
        db=db,
        latitude=lat,
        longitude=lng,
        limit=limit,
    )
    return ads
