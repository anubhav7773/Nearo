import enum
import uuid

from geoalchemy2 import Geometry
from sqlalchemy import (
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


class SOSStatus(str, enum.Enum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    FALSE_ALARM = "false_alarm"


class SOSEvent(Base):
    __tablename__ = "sos_events"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("uuid_generate_v4()"),
    )
    triggered_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    category = Column(
        String(50), nullable=False, default="security"
    )  # 'medical', 'security', 'fire', 'scam', 'other'
    description = Column(Text, nullable=True)
    location = Column(
        Geometry(geometry_type="POINT", srid=4326),
        nullable=True,
    )
    initial_location = Column(
        Geometry(geometry_type="POINT", srid=4326),
        nullable=False,
    )
    current_location = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True),
        nullable=False,
    )
    status = Column(
        Enum(
            SOSStatus,
            name="sos_status",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        default=SOSStatus.ACTIVE,
        nullable=False,
        index=True,
    )
    responders_count = Column(Integer, default=0, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    @property
    def emergency_type(self) -> str:
        return self.category or "security"

    @emergency_type.setter
    def emergency_type(self, value: str):
        self.category = value

    # Relationships
    user = relationship("User", back_populates="sos_events")
