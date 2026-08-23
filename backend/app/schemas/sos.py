import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.sos import SOSStatus


class SOSCreate(BaseModel):
    category: str | None = Field(None, description="Emergency category: medical, security, fire, scam")
    emergency_type: str | None = Field(None, description="Emergency category alias")
    description: str | None = Field(None, description="Additional context or caller description")
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)

    @model_validator(mode="after")
    def validate_category_or_type(self):
        if not self.category and not self.emergency_type:
            self.category = "security"
            self.emergency_type = "security"
        elif not self.emergency_type and self.category:
            self.emergency_type = self.category
        elif not self.category and self.emergency_type:
            self.category = self.emergency_type
        return self


class SOSBroadcastResponse(BaseModel):
    event_id: uuid.UUID
    sos_id: uuid.UUID | None = None
    status: str = "active"
    category: str = "security"
    broadcast_radius_meters: int = 1500
    dispatched_neighbors_count: int = 0
    dispatched_notifications_count: int = 0
    created_at: datetime | None = None

    @model_validator(mode="after")
    def populate_aliases(self):
        if not self.sos_id:
            self.sos_id = self.event_id
        if self.dispatched_neighbors_count and not self.dispatched_notifications_count:
            self.dispatched_notifications_count = self.dispatched_neighbors_count
        elif self.dispatched_notifications_count and not self.dispatched_neighbors_count:
            self.dispatched_neighbors_count = self.dispatched_notifications_count
        return self


class SOSEventDetail(BaseModel):
    id: uuid.UUID
    event_id: uuid.UUID | None = None
    triggered_by: uuid.UUID
    category: str = "security"
    emergency_type: str = "security"
    description: str | None = None
    status: SOSStatus
    responders_count: int = 0
    dispatched_neighbors_count: int = 0
    latitude: float
    longitude: float
    distance_meters: int | None = None
    created_at: datetime | None = None
    resolved_at: datetime | None = None

    @model_validator(mode="after")
    def populate_aliases(self):
        if not self.event_id:
            self.event_id = self.id
        if not self.category and self.emergency_type:
            self.category = self.emergency_type
        return self

    model_config = ConfigDict(from_attributes=True)


class SOSResolveResponse(BaseModel):
    success: bool = True
    event_id: uuid.UUID
    status: str = "resolved"
    resolved_at: datetime | None = None


class ActiveSOSResponse(BaseModel):
    has_active: bool = False
    event: SOSEventDetail | None = None
