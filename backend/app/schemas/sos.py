import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.sos import SOSStatus


class SOSCreate(BaseModel):
    emergency_type: str = Field(..., description="e.g. medical, security, fire, scam")
    description: str | None = Field(
        None, description="Additional context or caller description"
    )
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)


class SOSBroadcastResponse(BaseModel):
    sos_id: uuid.UUID
    status: str = "active"
    broadcast_radius_meters: int = 1500
    dispatched_notifications_count: int = 0


class SOSEventDetail(BaseModel):
    id: uuid.UUID
    triggered_by: uuid.UUID
    emergency_type: str
    description: str | None = None
    status: SOSStatus
    responders_count: int = 0
    latitude: float
    longitude: float
    distance_meters: int | None = None
    created_at: datetime
    resolved_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
