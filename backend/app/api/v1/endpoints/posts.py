import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from redis.asyncio import Redis
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.core.database import get_db
from app.core.redis import check_rate_limit, get_redis
from app.models.post import Comment, Post, PostUpvote
from app.models.user import User
from app.schemas.post import (
    CommentCreate,
    CommentResponse,
    FeedResponse,
    PostCreate,
    PostCreateResponse,
    PostResponse,
    PostUpvoteResponse,
)
from app.services.ad_engine import AdEngine
from app.services.geo_service import GeoService

logger = logging.getLogger(__name__)
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
async def get_nearby_posts(
    request: Request,
    lat: float | None = Query(None, description="Current user latitude"),
    lng: float | None = Query(None, description="Current user longitude"),
    latitude: float | None = Query(None, description="Current user latitude alias"),
    longitude: float | None = Query(None, description="Current user longitude alias"),
    radius_meters: int = Query(
        5000, ge=100, le=50000, description="Search radius in meters"
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
    user_lat = lat if lat is not None else latitude
    user_lon = lng if lng is not None else longitude

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

    # 3. Query Spatial Posts with normalized category filtering and PostGIS geometry
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

    # 4. Fetch Native Ads with graceful degradation
    native_ads = []
    try:
        native_ads = await AdEngine.fetch_nearby_active_ads(
            db=db,
            latitude=user_lat,
            longitude=user_lon,
            limit=5,
        )
    except Exception as ad_err:
        logger.warning(f"Ad fetch failed, continuing without ads: {ad_err}")
        native_ads = []

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

    content_text = payload.content or payload.body or ""
    title_text = payload.title or (content_text[:40] if content_text else "Local Update")
    lat = payload.latitude or payload.lat or 26.7922
    lng = payload.longitude or payload.lng or 82.1998
    cat_val = (
        payload.category.value
        if hasattr(payload.category, "value")
        else str(payload.category).lower().replace(" ", "_")
    )
    post_id = uuid.uuid4()

    try:
        sql = """
            INSERT INTO public.posts (
                id, user_id, author_id, title, content, body, category,
                location, media_urls, is_pinned, is_verified, upvotes_count, comments_count,
                created_at, updated_at
            ) VALUES (
                :id, :user_id, :author_id, :title, :content, :body, :category,
                ST_SetSRID(ST_MakePoint(:lng, :lat), 4326),
                :media_urls, false, false, 0, 0,
                NOW(), NOW()
            )
            RETURNING id, created_at;
        """
        params = {
            "id": post_id,
            "user_id": current_user.id,
            "author_id": current_user.id,
            "title": title_text,
            "content": content_text,
            "body": content_text,
            "category": cat_val,
            "lat": lat,
            "lng": lng,
            "media_urls": payload.media_urls or [],
        }
        res = await db.execute(text(sql), params)
        await db.commit()
        row = res.mappings().first()
        created_at_val = (
            row["created_at"] if row and "created_at" in row else datetime.now()
        )

        tier_val = (
            current_user.tier.value
            if hasattr(current_user.tier, "value")
            else str(getattr(current_user, "tier", "free") or "free")
        )

        return PostCreateResponse(
            id=row["id"] if row and "id" in row else post_id,
            status="published",
            created_at=created_at_val,
            title=title_text,
            content=content_text,
            category=cat_val,
            author_alias=getattr(current_user, "alias_name", None) or "Citizen",
            author_tier=tier_val,
            author_avatar_url=getattr(current_user, "avatar_url", None),
            latitude=lat,
            longitude=lng,
            distance_meters=0,
            distance_text="Just now · Here",
            media_urls=payload.media_urls or [],
        )
    except Exception as err:
        await db.rollback()
        logger.error("Post creation failed: %s", str(err))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create post: {str(err)}",
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
    try:
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
    except HTTPException:
        raise
    except Exception as err:
        await db.rollback()
        logger.error("Upvote toggle error: %s", str(err))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to toggle upvote: {str(err)}",
        )


@router.get(
    "/{post_id}/comments",
    response_model=list[CommentResponse],
    summary="Get Post Comments",
    description="Returns a list of comments for the specified post ordered by created_at ASC including author alias and avatar.",
)
async def get_post_comments(
    post_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    try:
        stmt = (
            select(
                Comment.id,
                Comment.post_id,
                Comment.author_id,
                Comment.content,
                Comment.created_at,
                User.alias_name.label("author_alias"),
                User.avatar_url.label("author_avatar_url"),
                User.tier.label("author_tier"),
            )
            .join(User, Comment.author_id == User.id)
            .where(Comment.post_id == post_id)
            .order_by(Comment.created_at.asc())
        )
        res = await db.execute(stmt)
        rows = res.mappings().all()

        comments = []
        for row in rows:
            tier_val = (
                row["author_tier"].value
                if hasattr(row["author_tier"], "value")
                else str(row["author_tier"] or "free")
            )
            comments.append(
                CommentResponse(
                    id=row["id"],
                    post_id=row["post_id"],
                    author_id=row["author_id"],
                    author_alias=row["author_alias"] or "Citizen",
                    author_avatar_url=row["author_avatar_url"],
                    author_tier=tier_val,
                    content=row["content"],
                    created_at=row["created_at"],
                )
            )
        return comments
    except Exception as err:
        logger.error("Failed to fetch comments for post %s: %s", post_id, str(err))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch comments: {str(err)}",
        )


@router.post(
    "/{post_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Post Comment",
    description="Inserts comment into comments table, increments comments_count on post, and returns new comment.",
)
async def create_post_comment(
    post_id: uuid.UUID,
    payload: CommentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: Redis | None = Depends(get_redis),
):
    # Rate limit check (30 comments / minute)
    rate_key = f"ratelimit:post_comment:{current_user.id}"
    if redis:
        allowed = await check_rate_limit(
            redis, rate_key, max_requests=30, window_seconds=60
        )
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Comment rate limit exceeded. Please wait a moment.",
            )

    try:
        # 1. Verify post exists
        post_stmt = select(Post).where(Post.id == post_id)
        post_res = await db.execute(post_stmt)
        post = post_res.scalar_one_or_none()
        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Post not found",
            )

        comment_id = uuid.uuid4()
        now_dt = datetime.now()

        new_comment = Comment(
            id=comment_id,
            post_id=post_id,
            author_id=current_user.id,
            content=payload.content.strip(),
            created_at=now_dt,
            updated_at=now_dt,
        )
        db.add(new_comment)

        # 2. Increment comments_count on post
        if hasattr(post, "comments_count"):
            post.comments_count = (post.comments_count or 0) + 1

        await db.commit()

        tier_val = (
            current_user.tier.value
            if hasattr(current_user.tier, "value")
            else str(getattr(current_user, "tier", "free") or "free")
        )

        return CommentResponse(
            id=comment_id,
            post_id=post_id,
            author_id=current_user.id,
            author_alias=getattr(current_user, "alias_name", None) or "Citizen",
            author_avatar_url=getattr(current_user, "avatar_url", None),
            author_tier=tier_val,
            content=payload.content.strip(),
            created_at=now_dt,
        )
    except HTTPException:
        raise
    except Exception as err:
        await db.rollback()
        logger.error("Failed to create comment for post %s: %s", post_id, str(err))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to post comment: {str(err)}",
        )

