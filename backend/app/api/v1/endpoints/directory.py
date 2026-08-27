import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.models.business import Business
from app.models.user import User
from app.schemas.directory import (
    BusinessListResponse,
    BusinessRegisterRequest,
    BusinessRegisterResponse,
    BusinessResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get(
    "",
    response_model=BusinessListResponse,
    summary="Get Nearby Verified Hyperlocal Businesses",
    description=(
        "Returns businesses within the spatial radius sorted ascending "
        "by distance with WhatsApp deep-link information."
    ),
)
async def get_nearby_directory(
    lat: float | None = Query(None, description="User latitude"),
    lng: float | None = Query(None, description="User longitude"),
    radius_meters: int = Query(
        3000, ge=100, le=20000, description="Spatial search radius in meters"
    ),
    category: str | None = Query(None, description="Category filter"),
    current_user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    user_lat = float(lat) if lat is not None else 26.7922
    user_lon = float(lng) if lng is not None else 82.1998

    params: dict = {
        "lat": user_lat,
        "lng": user_lon,
        "radius_meters": radius_meters,
    }
    category_filter = ""
    if category and category.lower().strip() not in ("all", "all categories", ""):
        category_filter = "AND b.category = :category"
        params["category"] = category.lower().strip().replace(" ", "_")

    sql = f"""
        SELECT b.id, b.name, b.category, b.description, b.whatsapp_number, b.is_verified, b.created_at,
               ROUND(ST_Distance(ST_Transform(b.location, 3857), ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 3857)))
               AS distance_meters
        FROM public.businesses b
        WHERE b.is_active = true
          AND ST_DWithin(ST_Transform(b.location, 3857), ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 3857), :radius_meters)
          {category_filter}
        ORDER BY distance_meters ASC, b.is_verified DESC;
    """
    try:
        result = await db.execute(text(sql), params)
        rows = result.mappings().all()

        business_list: list[BusinessResponse] = []
        for r in rows:
            dist_int = int(r["distance_meters"]) if r.get("distance_meters") is not None else None
            if dist_int is not None:
                dist_text = f"{dist_int}m away" if dist_int < 1000 else f"{dist_int / 1000.0:.1f} km away"
            else:
                dist_text = "Nearby"

            business_list.append(
                BusinessResponse(
                    id=r["id"],
                    name=r["name"],
                    category=r["category"],
                    description=r.get("description"),
                    whatsapp_number=r["whatsapp_number"],
                    distance_meters=dist_int,
                    distance_text=dist_text,
                    is_verified=bool(r.get("is_verified", False)),
                    created_at=r.get("created_at"),
                )
            )

        return BusinessListResponse(
            total_items=len(business_list),
            data=business_list,
        )
    except Exception as err:
        await db.rollback()
        logger.error("Directory spatial query error: %s", str(err))
        return BusinessListResponse(
            total_items=0,
            data=[],
        )


@router.post(
    "/register",
    response_model=BusinessRegisterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register Local Business Listing",
    description="Registers a neighborhood vendor or service with GPS coordinates and WhatsApp contact.",
)
async def register_business(
    payload: BusinessRegisterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        lat = float(payload.latitude or payload.lat or 26.7922)
        lng = float(payload.longitude or payload.lng or 82.1998)

        point_geom = func.ST_SetSRID(func.ST_MakePoint(lng, lat), 4326)

        clean_phone = payload.whatsapp_number.strip()
        if not clean_phone.startswith("+"):
            clean_phone = f"+91{clean_phone}" if len(clean_phone) == 10 else f"+{clean_phone}"

        new_biz = Business(
            id=uuid.uuid4(),
            owner_id=current_user.id,
            name=payload.name.strip(),
            category=payload.category.lower().replace(" ", "_"),
            description=payload.description.strip() if payload.description else None,
            whatsapp_number=clean_phone,
            location=point_geom,
            is_verified=False,
            is_active=True,
        )
        db.add(new_biz)
        await db.commit()
        await db.refresh(new_biz)

        created_at_val = (
            new_biz.created_at
            if hasattr(new_biz, "created_at") and isinstance(new_biz.created_at, datetime)
            else None
        )

        return BusinessRegisterResponse(
            id=new_biz.id,
            name=new_biz.name,
            category=new_biz.category,
            status="active",
            created_at=created_at_val,
        )
    except Exception as err:
        await db.rollback()
        logger.error("Error registering business: %s", str(err))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Business registration failed: {str(err)}",
        )
