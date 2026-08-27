import uuid

from geoalchemy2 import Geography, Geometry
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Index, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Business(Base):
    __tablename__ = "businesses"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("uuid_generate_v4()"),
    )
    owner_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    name = Column(String(120), nullable=False)
    category = Column(String(50), nullable=False, default="general", index=True)
    description = Column(Text, nullable=True)
    whatsapp_number = Column(String(20), nullable=False)
    location = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True),
        nullable=False,
    )
    is_verified = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    owner = relationship("User", backref="businesses")

    __table_args__ = (
        Index("idx_businesses_category", "category"),
        Index("idx_businesses_active", "is_active"),
    )
