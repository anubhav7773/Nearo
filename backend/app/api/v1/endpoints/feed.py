import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from redis.asyncio import Redis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.core.redis import check_rate_limit, get_redis
from app.models.post import Post, PostUpvote
from app.models.user import User
from app.schemas.post import (
    FeedResponse,
    PostCreate,
    PostCreateResponse,
    PostUpvoteResponse,
)
from app.services.ad_engine import AdEngine
from app.services.geo_service import GeoService

router = APIRouter()


@router.get(
    "/feed",
    response_model=FeedResponse,
    summary="Fetch Hyperlocal Radius Feed",
    description="Returns community posts within geographic radius with native ad cards injected at fixed intervals.",
)
@router.get(
    "",
    response_model=FeedResponse,
    summary="Fetch Hyperlocal Posts",
    description="Returns community posts within geographic radius matching optional category filters.",
)
async def get_feed(
    request: Request,
    lat: float | None = Query(None, description="Current user latitude"),
    lng: float | None = Query(None, description="Current user longitude"),
    radius_meters: int = Query(
        1500, ge=500, le=5000, description="Search radius in meters"
    ),
    category: str | None = Query(None, description="Optional category filter"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(15, ge=1, le=50, description="Items per page"),
    current_user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
    redis: Redis | None = Depends(get_redis),
):
    # 1. Rate Limiting Check (60 requests / minute per user/IP)
    ident = (
        str(current_user.id)
        if current_user
        else (request.client.host if request.client else "anon")
    )
    rate_key = f"ratelimit:feed:{ident}"
    if redis:
        allowed = await check_rate_limit(
            redis, rate_key, max_requests=60, window_seconds=60
        )
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
                user_lat = 26.7922
                user_lon = 82.1998
            else:
                user_lat, user_lon = 26.7922, 82.1998
        else:
            user_lat, user_lon = 26.7922, 82.1998

    # 3. Query Spatial Posts
    current_user_id = current_user.id if current_user else None
    posts, total_count = await GeoService.fetch_nearby_posts(
        db=db,
        latitude=user_lat,
        longitude=user_lon,
        radius_meters=radius_meters,
        category=category,
        current_user_id=current_user_id,
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
    redis: Redis | None = Depends(get_redis),
):
    # 1. Rate Limiting Check (10 posts / hour per User UUID)
    rate_key = f"ratelimit:post_create:{current_user.id}"
    if redis:
        allowed = await check_rate_limit(
            redis, rate_key, max_requests=10, window_seconds=3600
        )
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Post creation limit reached (maximum 10 posts per hour).",
            )

    # 2. Insert Post with Point geometry
    content_text = payload.content or payload.body or ""
    point_geom = func.ST_SetSRID(
        func.ST_MakePoint(payload.longitude, payload.latitude), 4326
    )
    new_post = Post(
        id=uuid.uuid4(),
        author_id=current_user.id,
        category=payload.category,
        title=payload.title,
        content=content_text,
        media_urls=payload.media_urls,
        location=point_geom,
        is_pinned=False,
        upvotes_count=0,
        comments_count=0,
    )
    db.add(new_post)
    await db.commit()
    await db.refresh(new_post)
    created_at_val = (
        new_post.created_at
        if hasattr(new_post, "created_at") and isinstance(new_post.created_at, datetime)
        else None
    )

    return PostCreateResponse(
        id=new_post.id,
        status="published",
        created_at=created_at_val,
    )


@router.post(
    "/{post_id}/upvote",
    response_model=PostUpvoteResponse,
    summary="Toggle Upvote on Post",
    description="Atomically increments or decrements post upvotes count and tracks user vote state.",
)
async def toggle_post_upvote(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # 1. Fetch target post
    post_stmt = select(Post).where(Post.id == post_id)
    post_res = await db.execute(post_stmt)
    post = post_res.scalar_one_or_none()

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found",
        )

    # 2. Check if user already upvoted
    upvote_stmt = select(PostUpvote).where(
        PostUpvote.user_id == current_user.id,
        PostUpvote.post_id == post_id,
    )
    upvote_res = await db.execute(upvote_stmt)
    existing_upvote = upvote_res.scalar_one_or_none()

    current_count = getattr(post, "upvotes_count", 0) or 0

    if existing_upvote:
        # Toggle off / remove upvote
        del_res = db.delete(existing_upvote)
        if hasattr(del_res, "__await__"):
            await del_res
        new_count = max(0, current_count - 1)
        if hasattr(post, "upvotes_count"):
            post.upvotes_count = new_count
        has_upvoted = False
    else:
        # Toggle on / add upvote
        new_upvote = PostUpvote(
            user_id=current_user.id,
            post_id=post_id,
        )
        db.add(new_upvote)
        new_count = current_count + 1
        if hasattr(post, "upvotes_count"):
            post.upvotes_count = new_count
        has_upvoted = True

    await db.commit()
    await db.refresh(post)

    return PostUpvoteResponse(
        success=True,
        post_id=post_id,
        upvotes_count=new_count,
        has_upvoted=has_upvoted,
    )
