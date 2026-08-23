import enum
import uuid
from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from app.core.database import Base
from app.models.user import SubscriptionTier


class AdType(str, enum.Enum):
    IN_FEED_CARD = "in_feed_card"
    DIRECTORY_TOP = "directory_top"


class LocalAd(Base):
    __tablename__ = "local_ads"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("uuid_generate_v4()"),
    )
    business_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    ad_type = Column(
        Enum(AdType, name="ad_type", native_enum=True, values_callable=lambda obj: [e.value for e in obj]),
        default=AdType.IN_FEED_CARD,
        nullable=False,
    )
    business_name = Column(String(100), nullable=False)
    tagline = Column(String(150), nullable=True)
    cta_title = Column(String(50), default="Contact on WhatsApp", nullable=True)
    whatsapp_number = Column(String(15), nullable=True)
    target_center = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True),
        nullable=False,
    )
    target_radius_meters = Column(Integer, default=3000, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    impressions_count = Column(BigInteger, default=0, nullable=False)
    clicks_count = Column(BigInteger, default=0, nullable=False)
    starts_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    business = relationship("User", back_populates="ads")

    __table_args__ = (
        Index("idx_local_ads_active", "is_active", "expires_at"),
    )


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("uuid_generate_v4()"),
    )
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tier = Column(
        Enum(SubscriptionTier, name="subscription_tier", native_enum=True, values_callable=lambda obj: [e.value for e in obj]),
        nullable=False,
    )
    amount = Column(Numeric(10, 2), nullable=False)
    gateway_order_id = Column(String(100), nullable=True)
    gateway_payment_id = Column(String(100), nullable=True)
    starts_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="subscriptions")

    __table_args__ = (
        Index("idx_subscriptions_user", "user_id", "is_active"),
    )
