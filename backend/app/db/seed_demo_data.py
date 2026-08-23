import asyncio
import logging
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import func, select, text

from app.core.config import settings
from app.core.database import AsyncSessionLocal, engine
from app.models.ad import AdType, LocalAd, Subscription
from app.models.post import Post, PostCategory
from app.models.sos import SOSEvent, SOSStatus
from app.models.user import SubscriptionTier, User, UserLocation, UserRole

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nearo.seed")


async def check_database_connection() -> bool:
    """Verify database connectivity with a lightweight query."""
    try:
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT 1"))
            return result.scalar() == 1
    except Exception as e:
        logger.error(f"Database connection check failed: {e}")
        return False


async def seed_data():
    """Seed comprehensive demo data for Nearo platform verification."""
    logger.info("Starting Nearo demo data seeding...")

    is_connected = await check_database_connection()
    if not is_connected:
        logger.warning(
            f"Could not connect to PostgreSQL at {settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}. "
            "Please ensure the database container is started."
        )
        return

    async with AsyncSessionLocal() as session:
        # Check if demo users already exist
        check_user = await session.execute(
            select(User).where(User.phone_number == "+919876543210")
        )
        if check_user.scalar_one_or_none():
            logger.info("Demo data already seeded. Skipping...")
            return

        now = datetime.now(timezone.utc)

        # ----------------------------------------------------------------------
        # 1. Seed 5 Verified Resident Users
        # ----------------------------------------------------------------------
        logger.info("Seeding verified resident profiles...")
        users = [
            User(
                id=uuid.uuid4(),
                phone_number="+919876543210",
                alias_name="AyodhyaResident_04",
                role=UserRole.RESIDENT,
                tier=SubscriptionTier.PRO_RESIDENT,
                is_verified=True,
                is_active=True,
            ),
            User(
                id=uuid.uuid4(),
                phone_number="+919876543211",
                alias_name="Nagarik_99",
                role=UserRole.RESIDENT,
                tier=SubscriptionTier.FREE,
                is_verified=True,
                is_active=True,
            ),
            User(
                id=uuid.uuid4(),
                phone_number="+919876543212",
                alias_name="KalyanSamiti_2",
                role=UserRole.MODERATOR,
                tier=SubscriptionTier.FREE,
                is_verified=True,
                is_active=True,
            ),
            User(
                id=uuid.uuid4(),
                phone_number="+919876543213",
                alias_name="Dr_Gupta_Admin",
                role=UserRole.BUSINESS,
                tier=SubscriptionTier.BUSINESS_PRO,
                is_verified=True,
                is_active=True,
            ),
            User(
                id=uuid.uuid4(),
                phone_number="+919876543214",
                alias_name="Parihar_Merchant",
                role=UserRole.BUSINESS,
                tier=SubscriptionTier.BUSINESS_PRO,
                is_verified=True,
                is_active=True,
            ),
        ]
        session.add_all(users)
        await session.flush()

        # ----------------------------------------------------------------------
        # 2. Seed User Locations around Ayodhya Central (26.7922° N, 82.1998° E)
        # ----------------------------------------------------------------------
        logger.info("Seeding resident GPS coordinates & geofences...")
        offsets = [
            (0.0000, 0.0000),
            (0.0025, 0.0018),
            (-0.0031, 0.0022),
            (0.0042, -0.0035),
            (-0.0015, -0.0028),
        ]
        user_locations = [
            UserLocation(
                user_id=users[i].id,
                pincode="224001",
                last_known_location=func.ST_SetSRID(
                    func.ST_MakePoint(82.1998 + offsets[i][1], 26.7922 + offsets[i][0]),
                    4326,
                ),
                preferred_radius_meters=1500,
            )
            for i in range(5)
        ]
        session.add_all(user_locations)

        # ----------------------------------------------------------------------
        # 3. Seed 10 Realistic Community Posts
        # ----------------------------------------------------------------------
        logger.info("Seeding neighborhood community posts...")
        posts_data = [
            (
                users[1].id,
                PostCategory.CIVIC_ISSUE,
                "Sector 4 Water Supply Line Maintenance",
                "The municipal water line repair is ongoing near Gate #2. Supply expected to normalize by 5 PM today.",
                (0.0012, 0.0010),
                14,
                3,
                True,
            ),
            (
                users[0].id,
                PostCategory.ALERT,
                "Cyber Scam: Fake Electricity Bill Disconnection SMS",
                (
                    "Residents received fraud SMS asking to call an unknown number "
                    "for immediate bill clearance. Do not share OTPs!"
                ),
                (0.0005, 0.0008),
                28,
                8,
                False,
            ),
            (
                users[2].id,
                PostCategory.HELP_NEEDED,
                "Urgent B+ Blood Donor Needed at District Hospital",
                (
                    "Emergency patient admitted in trauma ward. Anyone available near "
                    "Civil Lines please contact hospital reception directly."
                ),
                (0.0020, -0.0015),
                45,
                12,
                False,
            ),
            (
                users[1].id,
                PostCategory.CIVIC_ISSUE,
                "Streetlights Malfunctioning on Bypass Road",
                (
                    "3 consecutive solar streetlights are flickering on Bypass Marg. "
                    "Reported to municipal board ticket #AY8821."
                ),
                (-0.0018, 0.0025),
                8,
                1,
                False,
            ),
            (
                users[4].id,
                PostCategory.TRADE,
                "Fresh Organic Malihabad Mangoes Available",
                "Direct harvest delivered from orchards. Available at Shop #12 near Central Mandir Chowk.",
                (-0.0010, -0.0012),
                11,
                4,
                False,
            ),
            (
                users[0].id,
                PostCategory.GENERAL,
                "Sunday Neighborhood Cleanliness Drive",
                "Join us this Sunday at 7:00 AM at Community Park for the voluntary green sanitation initiative.",
                (0.0008, -0.0006),
                19,
                5,
                False,
            ),
            (
                users[2].id,
                PostCategory.ALERT,
                "Suspicious Door-to-Door Gas Cylinder Inspection",
                "Two unidentified individuals claiming to be agency inspectors without official badges. Stay vigilant!",
                (0.0030, 0.0020),
                34,
                9,
                False,
            ),
            (
                users[1].id,
                PostCategory.HELP_NEEDED,
                "Lost Golden Retriever Puppy near Ram Path",
                "Wearing a red collar, responds to 'Leo'. Please contact if spotted near Ram Ki Paidi.",
                (-0.0025, -0.0020),
                22,
                6,
                False,
            ),
            (
                users[0].id,
                PostCategory.CIVIC_ISSUE,
                "Garbage Collection Timing Update",
                "Morning waste collection vehicle will arrive at 8:30 AM instead of 7:30 AM during rainy conditions.",
                (0.0015, 0.0032),
                6,
                0,
                False,
            ),
            (
                users[4].id,
                PostCategory.TRADE,
                "Handmade Terracotta Diya & Pottery Stalls",
                "Local artisans setting up exhibitions at Cultural Square through this weekend.",
                (0.0002, 0.0015),
                16,
                2,
                False,
            ),
        ]

        for (
            author_id,
            cat,
            title,
            content,
            offset,
            upvotes,
            comments,
            pinned,
        ) in posts_data:
            post = Post(
                author_id=author_id,
                category=cat,
                title=title,
                content=content,
                location=func.ST_SetSRID(
                    func.ST_MakePoint(82.1998 + offset[1], 26.7922 + offset[0]),
                    4326,
                ),
                is_pinned=pinned,
                upvotes_count=upvotes,
                comments_count=comments,
                created_at=now - timedelta(minutes=upvotes * 8),
            )
            session.add(post)

        # ----------------------------------------------------------------------
        # 4. Seed 2 Hyperlocal Native Ads
        # ----------------------------------------------------------------------
        logger.info("Seeding native sponsor advertisements...")
        ads = [
            LocalAd(
                business_id=users[3].id,
                ad_type=AdType.IN_FEED_CARD,
                business_name="Gupta Diagnostic Center",
                tagline="Special 20% off comprehensive health checkups for verified neighborhood residents.",
                cta_title="Chat on WhatsApp",
                whatsapp_number="+919876543213",
                target_center=func.ST_SetSRID(
                    func.ST_MakePoint(82.1998, 26.7922), 4326
                ),
                target_radius_meters=3000,
                is_active=True,
                impressions_count=142,
                clicks_count=29,
                starts_at=now - timedelta(days=2),
                expires_at=now + timedelta(days=28),
            ),
            LocalAd(
                business_id=users[4].id,
                ad_type=AdType.IN_FEED_CARD,
                business_name="Ayodhya Electricians & Solar",
                tagline="Emergency home wiring repair, inverter maintenance, and rooftop solar installation.",
                cta_title="Contact on WhatsApp",
                whatsapp_number="+919876543214",
                target_center=func.ST_SetSRID(
                    func.ST_MakePoint(82.2010, 26.7930), 4326
                ),
                target_radius_meters=3000,
                is_active=True,
                impressions_count=98,
                clicks_count=15,
                starts_at=now - timedelta(days=1),
                expires_at=now + timedelta(days=29),
            ),
        ]
        session.add_all(ads)

        # ----------------------------------------------------------------------
        # 5. Seed 1 Active Civic SOS Emergency Alert
        # ----------------------------------------------------------------------
        logger.info("Seeding active Civic SOS emergency...")
        sos_event = SOSEvent(
            triggered_by=users[1].id,
            emergency_type="security",
            description="Suspicious individuals attempting forced entry claiming fake digital verification.",
            initial_location=func.ST_SetSRID(func.ST_MakePoint(82.1990, 26.7930), 4326),
            current_location=func.ST_SetSRID(func.ST_MakePoint(82.1990, 26.7930), 4326),
            status=SOSStatus.ACTIVE,
            responders_count=4,
            created_at=now - timedelta(minutes=10),
        )
        session.add(sos_event)

        # ----------------------------------------------------------------------
        # 6. Seed Subscriptions
        # ----------------------------------------------------------------------
        subscription = Subscription(
            user_id=users[0].id,
            tier=SubscriptionTier.PRO_RESIDENT,
            amount=Decimal("29.00"),
            gateway_order_id="order_NX992817A",
            gateway_payment_id="pay_demo_success_881",
            starts_at=now - timedelta(days=5),
            expires_at=now + timedelta(days=25),
            is_active=True,
        )
        session.add(subscription)

        await session.commit()
        logger.info("Nearo demo data successfully seeded into database!")


if __name__ == "__main__":
    asyncio.run(seed_data())
