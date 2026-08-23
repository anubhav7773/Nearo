from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from redis.asyncio import Redis
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.core.redis import check_rate_limit, get_redis
from app.models.post import Post
from app.models.user import User
from app.schemas.post import FeedResponse, PostCreate, PostCreateResponse
from app.services.ad_engine import AdEngine
from app.services.geo_service import GeoService

router = APIRouter()


@router.get(
    "/feed",
    response_model=FeedResponse,
    summary="Fetch Hyperlocal Radius Feed",
    description="Returns community posts within geographic radius with native ad cards injected at fixed intervals.",
)
async def get_feed(
    request: Request,
    lat: Optional[float] = Query(None, description="Current user latitude"),
    lng: Optional[float] = Query(None, description="Current user longitude"),
    radius_meters: int = Query(1500, ge=500, le=5000, description="Search radius in meters"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(15, ge=1, le=50, description="Items per page"),
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
    redis: Optional[Redis] = Depends(get_redis),
):
    # 1. Rate Limiting Check (60 requests / minute per user/IP)
    ident = str(current_user.id) if current_user else (request.client.host if request.client else "anon")
    rate_key = f"ratelimit:feed:{ident}"
    if redis:
        allowed = await check_rate_limit(redis, rate_key, max_requests=60, window_seconds=60)
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Feed rate limit exceeded. Please wait a moment.",
            )

    # 2. Resolve user coordinates
    user_lat = lat
    user_lon = lng

    if user_lat is None or user_lon is None:
        if current_user:
            user_loc = await GeoService.get_user_location(db, current_user.id)
            if user_loc:
                # Default Ayodhya central fallback if geometry extraction needed
                user_lat = 26.7922
                user_lon = 82.1998
            else:
                user_lat, user_lon = 26.7922, 82.1998
        else:
            user_lat, user_lon = 26.7922, 82.1998

    # 3. Query Spatial Posts
    posts, total_count = await GeoService.fetch_nearby_posts(
        db=db,
        latitude=user_lat,
        longitude=user_lon,
        radius_meters=radius_meters,
        page=page,
        limit=limit,
    )

    # 4. Fetch Native Ads
    native_ads = await AdEngine.fetch_nearby_active_ads(
        db=db,
        latitude=user_lat,
        longitude=user_lon,
        limit=5,
    )

    # 5. Inject Ads (ad-free for pro_resident tier)
    user_tier = current_user.tier if current_user else None
    combined_data = AdEngine.inject_native_ads(
        posts=posts,
        ads=native_ads,
        user_tier=user_tier,
    )

    return FeedResponse(
        page=page,
        total_items=len(combined_data),
        data=combined_data,
    )


@router.post(
    "",
    response_model=PostCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Neighborhood Post",
    description="Publish a hyperlocal community update or civic issue bounded by GPS coordinates.",
)
async def create_post(
    payload: PostCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Optional[Redis] = Depends(get_redis),
):
    # 1. Rate Limiting Check (5 posts / hour per User UUID)
    rate_key = f"ratelimit:post_create:{current_user.id}"
    if redis:
        allowed = await check_rate_limit(redis, rate_key, max_requests=5, window_seconds=3600)
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Post creation limit reached (maximum 5 posts per hour).",
            )

    # 2. Insert Post with Point geometry
    point_geom = func.ST_SetSRID(func.ST_MakePoint(payload.longitude, payload.latitude), 4326)
    new_post = Post(
        author_id=current_user.id,
        category=payload.category,
        title=payload.title,
        content=payload.content,
        media_urls=payload.media_urls,
        location=point_geom,
        is_pinned=False,
        upvotes_count=0,
        comments_count=0,
    )
    db.add(new_post)
    await db.commit()
    await db.refresh(new_post)

    return PostCreateResponse(
        id=new_post.id,
        status="published",
        created_at=new_post.created_at,
    )
