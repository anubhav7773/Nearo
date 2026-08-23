import math
import random
import uuid

from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.post import Post
from app.models.user import User, UserLocation
from app.schemas.post import PostResponse


def apply_coordinate_jitter(
    lat: float,
    lon: float,
    min_meters: float = 75.0,
    max_meters: float = 125.0,
) -> tuple[float, float]:
    """Apply pseudo-random 75-125m Gaussian jitter to prevent resident triangulation (DPDP compliance)."""
    radius_meters = random.uniform(min_meters, max_meters)
    r = radius_meters / 111300.0  # Approximate conversion: meters to degrees
    u = random.random()
    v = random.random()
    w = r * math.sqrt(u)
    t = 2 * math.pi * v
    jitter_lat = w * math.cos(t)
    # Guard against division by zero near poles
    cos_lat = math.cos(math.radians(lat))
    jitter_lon = (
        (w * math.sin(t)) / cos_lat if abs(cos_lat) > 1e-6 else (w * math.sin(t))
    )
    return lat + jitter_lat, lon + jitter_lon


class GeoService:
    @staticmethod
    async def sync_user_location(
        db: AsyncSession,
        user_id: uuid.UUID,
        latitude: float,
        longitude: float,
        pincode: str,
        preferred_radius_meters: int = 1500,
    ) -> UserLocation:
        """Upsert user's current GPS coordinate and preferred radius boundary."""
        stmt = select(UserLocation).where(UserLocation.user_id == user_id)
        result = await db.execute(stmt)
        user_loc = result.scalar_one_or_none()

        geom_point = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)

        if user_loc:
            user_loc.last_known_location = geom_point
            user_loc.pincode = pincode
            user_loc.preferred_radius_meters = preferred_radius_meters
        else:
            user_loc = UserLocation(
                user_id=user_id,
                pincode=pincode,
                last_known_location=geom_point,
                preferred_radius_meters=preferred_radius_meters,
            )
            db.add(user_loc)

        await db.commit()
        await db.refresh(user_loc)
        return user_loc

    @staticmethod
    async def get_user_location(
        db: AsyncSession,
        user_id: uuid.UUID,
    ) -> UserLocation | None:
        """Fetch saved location coordinates for a user."""
        stmt = select(UserLocation).where(UserLocation.user_id == user_id)
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    @staticmethod
    async def fetch_nearby_posts(
        db: AsyncSession,
        latitude: float,
        longitude: float,
        radius_meters: int = 1500,
        category: str | None = None,
        current_user_id: uuid.UUID | None = None,
        page: int = 1,
        limit: int = 15,
    ) -> tuple[list[PostResponse], int]:
        """Fetch posts within the geographic radius using PostGIS ST_DWithin and ST_Distance."""
        from app.models.post import PostCategory, PostUpvote

        offset = (page - 1) * limit
        point_geom = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)

        # Distance calculation in meters using PostGIS geography casting
        distance_expr = func.ST_Distance(
            func.cast(Post.location, text("geography")),
            func.cast(point_geom, text("geography")),
        ).label("distance_meters")

        # Extract raw coordinates for jittering (cast to geometry for ST_X/ST_Y)
        raw_lat = func.ST_Y(func.cast(Post.location, text("geometry"))).label("raw_lat")
        raw_lon = func.ST_X(func.cast(Post.location, text("geometry"))).label("raw_lon")

        # Base query joining author to retrieve profile metadata
        where_conditions = [
            func.ST_DWithin(
                func.cast(Post.location, text("geography")),
                func.cast(point_geom, text("geography")),
                radius_meters,
            )
        ]

        if category and category.lower() not in ("all", "all updates", ""):
            cat_val = category.lower().replace(" ", "_")
            # Map friendly tab names
            if "civic" in cat_val:
                cat_val = "civic_issue"
            elif "alert" in cat_val or "scam" in cat_val:
                cat_val = "alert"
            elif "help" in cat_val:
                cat_val = "help_needed"
            elif "trade" in cat_val:
                cat_val = "trade"
            elif "general" in cat_val:
                cat_val = "general"

            try:
                cat_enum = PostCategory(cat_val)
                where_conditions.append(Post.category == cat_enum)
            except ValueError:
                pass

        query = (
            select(
                Post,
                User.alias_name,
                User.tier,
                User.avatar_url,
                distance_expr,
                raw_lat,
                raw_lon,
            )
            .outerjoin(User, or_(Post.author_id == User.id, Post.user_id == User.id))
            .where(*where_conditions)
        )

        # Total count query for pagination
        count_query = select(func.count()).select_from(query.subquery())
        count_result = await db.execute(count_query)
        total_count = count_result.scalar_one() or 0

        # Execute paginated query with pinning and chronological ordering
        paginated_query = (
            query.order_by(Post.is_pinned.desc(), Post.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        results = await db.execute(paginated_query)
        rows = results.all()

        # Batch check user upvotes
        upvoted_post_ids: set[uuid.UUID] = set()
        if current_user_id and rows:
            post_ids = [row[0].id for row in rows if hasattr(row[0], "id")]
            if post_ids:
                upvote_stmt = select(PostUpvote.post_id).where(
                    PostUpvote.user_id == current_user_id,
                    PostUpvote.post_id.in_(post_ids),
                )
                upvote_res = await db.execute(upvote_stmt)
                upvoted_post_ids = set(upvote_res.scalars().all())

        post_responses: list[PostResponse] = []
        for post, alias_name, tier, avatar_url, distance, r_lat, r_lon in rows:
            # Apply anti-triangulation Gaussian coordinate jitter
            lat_val = float(r_lat) if r_lat is not None else latitude
            lon_val = float(r_lon) if r_lon is not None else longitude
            j_lat, j_lon = apply_coordinate_jitter(lat_val, lon_val)
            dist_int = int(distance) if distance is not None else None

            # Calculate human-readable distance text
            if dist_int is not None:
                if dist_int < 1000:
                    distance_text = f"{dist_int}m away"
                else:
                    distance_text = f"{dist_int / 1000.0:.1f} km away"
            else:
                distance_text = "Nearby"

            author_tier_str = tier.value if hasattr(tier, "value") else str(tier or "free")

            post_responses.append(
                PostResponse(
                    id=post.id,
                    author_alias=alias_name or "Resident",
                    author_tier=author_tier_str,
                    author_avatar_url=avatar_url,
                    category=(
                        post.category.value
                        if hasattr(post.category, "value")
                        else str(post.category)
                    ),
                    title=post.title,
                    content=post.content or getattr(post, "body", "") or "",
                    distance_meters=dist_int,
                    distance_text=distance_text,
                    upvotes=post.upvotes_count,
                    has_upvoted=post.id in upvoted_post_ids,
                    comments_count=post.comments_count,
                    latitude=round(j_lat, 6),
                    longitude=round(j_lon, 6),
                    media_urls=post.media_urls or [],
                    created_at=post.created_at,
                )
            )

        return post_responses, total_count
