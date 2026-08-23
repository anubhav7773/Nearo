import math
import random
import uuid

from sqlalchemy import func, select, text
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
        page: int = 1,
        limit: int = 15,
    ) -> tuple[list[PostResponse], int]:
        """Fetch posts within the geographic radius using PostGIS ST_DWithin and ST_Distance."""
        offset = (page - 1) * limit
        point_geom = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)

        # Distance calculation in meters using PostGIS geography casting
        distance_expr = func.ST_Distance(
            func.cast(Post.location, text("geography")),
            func.cast(point_geom, text("geography")),
        ).label("distance_meters")

        # Extract raw coordinates for jittering
        raw_lat = func.ST_Y(Post.location).label("raw_lat")
        raw_lon = func.ST_X(Post.location).label("raw_lon")

        # Base query joining author to retrieve alias_name
        query = (
            select(Post, User.alias_name, distance_expr, raw_lat, raw_lon)
            .join(User, Post.author_id == User.id)
            .where(
                func.ST_DWithin(
                    func.cast(Post.location, text("geography")),
                    func.cast(point_geom, text("geography")),
                    radius_meters,
                )
            )
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

        post_responses: list[PostResponse] = []
        for post, alias_name, distance, r_lat, r_lon in rows:
            # Apply anti-triangulation Gaussian coordinate jitter
            j_lat, j_lon = apply_coordinate_jitter(float(r_lat), float(r_lon))

            post_responses.append(
                PostResponse(
                    id=post.id,
                    author_alias=alias_name,
                    category=(
                        post.category.value
                        if hasattr(post.category, "value")
                        else str(post.category)
                    ),
                    title=post.title,
                    content=post.content,
                    distance_meters=int(distance) if distance is not None else None,
                    upvotes=post.upvotes_count,
                    comments_count=post.comments_count,
                    latitude=round(j_lat, 6),
                    longitude=round(j_lon, 6),
                    media_urls=post.media_urls or [],
                    created_at=post.created_at,
                )
            )

        return post_responses, total_count
