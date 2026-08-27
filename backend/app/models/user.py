import enum
import uuid

from geoalchemy2 import Geography, Geometry
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class UserRole(str, enum.Enum):
    RESIDENT = "resident"
    MODERATOR = "moderator"
    BUSINESS = "business"
    ADMIN = "admin"


class SubscriptionTier(str, enum.Enum):
    FREE = "free"
    PRO_RESIDENT = "pro_resident"
    BUSINESS_PRO = "business_pro"


class User(Base):
    __tablename__ = "users"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("uuid_generate_v4()"),
    )
    phone_number = Column(String(50), unique=True, nullable=True, index=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    firebase_uid = Column(String(255), unique=True, nullable=True, index=True)
    clerk_user_id = Column(String(255), unique=True, nullable=True, index=True)
    auth_provider = Column(String(50), default="firebase", nullable=False)
    alias_name = Column(String(50), nullable=False)
    avatar_url = Column(Text, nullable=True)
    fcm_token = Column(Text, nullable=True, index=True)
    role = Column(
        Enum(
            UserRole,
            name="user_role",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        default=UserRole.RESIDENT,
        nullable=False,
    )
    tier = Column(
        Enum(
            SubscriptionTier,
            name="subscription_tier",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        default=SubscriptionTier.FREE,
        nullable=False,
    )
    is_verified = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    location = relationship(
        "UserLocation",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    posts = relationship(
        "Post",
        back_populates="author",
        cascade="all, delete-orphan",
    )
    sos_events = relationship(
        "SOSEvent",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    ads = relationship(
        "LocalAd",
        back_populates="business",
        cascade="all, delete-orphan",
    )
    subscriptions = relationship(
        "Subscription",
        back_populates="user",
        cascade="all, delete-orphan",
    )


class UserLocation(Base):
    __tablename__ = "user_locations"

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    pincode = Column(String(10), nullable=False)
    last_known_location = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True),
        nullable=False,
    )
    preferred_radius_meters = Column(
        Integer,
        default=1500,
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint(
            "preferred_radius_meters BETWEEN 500 AND 5000",
            name="chk_preferred_radius_meters",
        ),
    )

    # Relationship back to User
    user = relationship("User", back_populates="location")
