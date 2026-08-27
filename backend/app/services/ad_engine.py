import urllib.parse
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ad import LocalAd
from app.models.user import SubscriptionTier
from app.schemas.ad import NativeAdResponse
from app.schemas.post import PostResponse


class AdEngine:
    @staticmethod
    async def fetch_nearby_active_ads(
        db: AsyncSession,
        latitude: float,
        longitude: float,
        limit: int = 5,
    ) -> list[NativeAdResponse]:
        """Fetch active native ads whose target radius covers the user coordinate."""
        try:
            point_geom = func.ST_SetSRID(
                func.ST_MakePoint(float(longitude), float(latitude)), 4326
            )
            now_utc = datetime.now(timezone.utc)

            distance_expr = func.ST_Distance(
                func.ST_Transform(LocalAd.target_center, 3857),
                func.ST_Transform(point_geom, 3857),
            ).label("distance_meters")

            stmt = (
                select(LocalAd, distance_expr)
                .where(
                    LocalAd.is_active.is_(True),
                    LocalAd.expires_at > now_utc,
                    func.ST_DWithin(
                        func.ST_Transform(LocalAd.target_center, 3857),
                        func.ST_Transform(point_geom, 3857),
                        LocalAd.target_radius_meters,
                    ),
                )
                .order_by(distance_expr.asc())
                .limit(limit)
            )

            result = await db.execute(stmt)
            rows = result.all()
        except Exception:
            return []

        ad_responses: list[NativeAdResponse] = []
        for ad, distance in rows:
            # Build WhatsApp direct click URL
            whatsapp_url = None
            if ad.whatsapp_number:
                clean_phone = (
                    ad.whatsapp_number.replace("+", "")
                    .replace(" ", "")
                    .replace("-", "")
                )
                msg = urllib.parse.quote(
                    f"Hi {ad.business_name}, I saw your offer on Nearo!"
                )
                whatsapp_url = f"https://wa.me/{clean_phone}?text={msg}"

            ad_responses.append(
                NativeAdResponse(
                    id=str(ad.id),
                    business_name=ad.business_name,
                    tagline=ad.tagline,
                    cta_title=ad.cta_title or "Contact on WhatsApp",
                    whatsapp_url=whatsapp_url,
                    distance_meters=int(distance) if distance is not None else None,
                )
            )

        return ad_responses

    @staticmethod
    def inject_native_ads(
        posts: list[PostResponse],
        ads: list[NativeAdResponse],
        user_tier: SubscriptionTier | str | None = None,
    ) -> list[PostResponse | NativeAdResponse]:
        """Inject 1 native ad after every 6th community post (cadence of 1 ad per 7 items)

        Subscribers with tier == 'pro_resident' receive 0 ad injections.
        """
        # Check pro resident ad-free benefit
        tier_str = (
            user_tier.value if hasattr(user_tier, "value") else str(user_tier or "")
        )
        if tier_str in (SubscriptionTier.PRO_RESIDENT.value, "pro_resident", "pro"):
            return list(posts)

        if not ads or not posts:
            return list(posts)

        combined_feed: list[PostResponse | NativeAdResponse] = []
        ad_index = 0
        total_ads = len(ads)

        for i, post in enumerate(posts, start=1):
            combined_feed.append(post)
            # Inject an ad after every 6 posts if ads are available
            if i % 6 == 0 and ad_index < total_ads:
                combined_feed.append(ads[ad_index])
                ad_index += 1

        return combined_feed
