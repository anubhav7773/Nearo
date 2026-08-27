import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.sos import SOSStatus


class SOSCreate(BaseModel):
    category: str | None = Field(None, description="Emergency category: medical, security, fire, scam, suspicious_activity, harassment")
    emergency_type: str | None = Field(None, description="Emergency category alias")
    description: str | None = Field("Civic SOS Emergency Broadcast", description="Additional context or caller description")
    latitude: float | None = Field(None, ge=-90.0, le=90.0)
    longitude: float | None = Field(None, ge=-180.0, le=180.0)
    lat: float | None = Field(None, ge=-90.0, le=90.0, description="Alias for latitude")
    lng: float | None = Field(None, ge=-180.0, le=180.0, description="Alias for longitude")
    radius_meters: float | None = Field(1500.0, description="Broadcast radius in meters")
    broadcast_radius_meters: float | None = Field(None, description="Alias for radius_meters")

    @model_validator(mode="after")
    def validate_fields(self):
        if not self.category and not self.emergency_type:
            self.category = "security"
            self.emergency_type = "security"
        elif not self.emergency_type and self.category:
            self.emergency_type = self.category
        elif not self.category and self.emergency_type:
            self.category = self.emergency_type

        if self.latitude is None and self.lat is not None:
            self.latitude = self.lat
        if self.longitude is None and self.lng is not None:
            self.longitude = self.lng
        if self.latitude is None or self.longitude is None:
            raise ValueError("Coordinates ('latitude'/'longitude' or 'lat'/'lng') are required.")

        if self.radius_meters is None and self.broadcast_radius_meters is not None:
            self.radius_meters = self.broadcast_radius_meters
        elif self.broadcast_radius_meters is None and self.radius_meters is not None:
            self.broadcast_radius_meters = self.radius_meters

        return self


# Alias schema for backwards-compatibility
SosCreateSchema = SOSCreate


class SOSBroadcastResponse(BaseModel):
    id: uuid.UUID | None = None
    event_id: uuid.UUID | None = None
    sos_id: uuid.UUID | None = None
    user_id: uuid.UUID | None = None
    triggered_by: uuid.UUID | None = None
    status: str = "active"
    category: str = "security"
    emergency_type: str | None = None
    description: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    lat: float | None = None
    lng: float | None = None
    broadcast_radius_meters: int = 1500
    radius_meters: float | None = 1500.0
    dispatched_count: int = 0
    dispatched_neighbors_count: int = 0
    dispatched_notifications_count: int = 0
    neighbors_alerted: int = 0
    neighbors_notified: int = 0
    created_at: datetime | None = None

    @model_validator(mode="after")
    def populate_aliases(self):
        main_id = self.id or self.event_id or self.sos_id
        if main_id:
            self.id = main_id
            self.event_id = main_id
            self.sos_id = main_id

        user_ident = self.user_id or self.triggered_by
        if user_ident:
            self.user_id = user_ident
            self.triggered_by = user_ident

        if not self.emergency_type and self.category:
            self.emergency_type = self.category
        elif not self.category and self.emergency_type:
            self.category = self.emergency_type

        if self.latitude is not None and self.lat is None:
            self.lat = self.latitude
        elif self.lat is not None and self.latitude is None:
            self.latitude = self.lat

        if self.longitude is not None and self.lng is None:
            self.lng = self.longitude
        elif self.lng is not None and self.longitude is None:
            self.longitude = self.lng

        count = (
            self.dispatched_count
            or self.dispatched_neighbors_count
            or self.dispatched_notifications_count
            or self.neighbors_alerted
            or self.neighbors_notified
            or 0
        )
        self.dispatched_count = count
        self.dispatched_neighbors_count = count
        self.dispatched_notifications_count = count
        self.neighbors_alerted = count
        self.neighbors_notified = count

        if self.broadcast_radius_meters and not self.radius_meters:
            self.radius_meters = float(self.broadcast_radius_meters)
        elif self.radius_meters and not self.broadcast_radius_meters:
            self.broadcast_radius_meters = int(self.radius_meters)

        return self

    model_config = ConfigDict(from_attributes=True)


SosResponseSchema = SOSBroadcastResponse


class SOSEventDetail(BaseModel):
    id: uuid.UUID
    event_id: uuid.UUID | None = None
    sos_id: uuid.UUID | None = None
    user_id: uuid.UUID | None = None
    triggered_by: uuid.UUID
    category: str = "security"
    emergency_type: str = "security"
    description: str | None = None
    status: SOSStatus
    responders_count: int = 0
    dispatched_count: int = 0
    dispatched_neighbors_count: int = 0
    dispatched_notifications_count: int = 0
    neighbors_alerted: int = 0
    neighbors_notified: int = 0
    latitude: float
    longitude: float
    lat: float | None = None
    lng: float | None = None
    broadcast_radius_meters: int = 1500
    radius_meters: float | None = 1500.0
    distance_meters: int | None = None
    created_at: datetime | None = None
    resolved_at: datetime | None = None

    @model_validator(mode="after")
    def populate_aliases(self):
        if not self.event_id:
            self.event_id = self.id
        if not self.sos_id:
            self.sos_id = self.id
        if not self.user_id:
            self.user_id = self.triggered_by

        if not self.category and self.emergency_type:
            self.category = self.emergency_type
        elif not self.emergency_type and self.category:
            self.emergency_type = self.category

        if self.latitude is not None and self.lat is None:
            self.lat = self.latitude
        if self.longitude is not None and self.lng is None:
            self.lng = self.longitude

        count = (
            self.dispatched_count
            or self.dispatched_neighbors_count
            or self.neighbors_alerted
            or self.neighbors_notified
            or 0
        )
        self.dispatched_count = count
        self.dispatched_neighbors_count = count
        self.neighbors_alerted = count
        self.neighbors_notified = count
        return self

    model_config = ConfigDict(from_attributes=True)


class SOSResolveResponse(BaseModel):
    success: bool = True
    event_id: uuid.UUID
    sos_id: uuid.UUID | None = None
    status: str = "resolved"
    resolved_at: datetime | None = None

    @model_validator(mode="after")
    def populate_aliases(self):
        if not self.sos_id:
            self.sos_id = self.event_id
        return self


class ActiveSOSResponse(BaseModel):
    has_active: bool = False
    event: SOSEventDetail | None = None
