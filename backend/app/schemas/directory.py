import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


class BusinessRegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=120, description="Business or Vendor Name")
    category: str = Field(
        ..., min_length=2, max_length=50, description="Category: healthcare, grocery, home_services, etc."
    )
    description: str | None = Field(None, max_length=500, description="Short business overview or services offered")
    whatsapp_number: str = Field(
        ..., pattern=r"^\+?[0-9]{10,15}$", description="WhatsApp contact number with country code"
    )
    latitude: float | None = Field(None, ge=-90.0, le=90.0)
    longitude: float | None = Field(None, ge=-180.0, le=180.0)
    lat: float | None = Field(None, ge=-90.0, le=90.0, description="Alias for latitude")
    lng: float | None = Field(None, ge=-180.0, le=180.0, description="Alias for longitude")

    @model_validator(mode="after")
    def validate_coordinates(self):
        if self.latitude is None and self.lat is not None:
            self.latitude = self.lat
        if self.longitude is None and self.lng is not None:
            self.longitude = self.lng
        if self.latitude is None or self.longitude is None:
            raise ValueError("Coordinates ('latitude'/'longitude' or 'lat'/'lng') are required.")
        return self


class BusinessRegisterResponse(BaseModel):
    id: uuid.UUID
    name: str
    category: str
    status: str = "active"
    created_at: datetime | None = None


class BusinessResponse(BaseModel):
    id: uuid.UUID
    name: str
    category: str
    description: str | None = None
    whatsapp_number: str
    distance_meters: int | None = None
    distance_text: str | None = None
    is_verified: bool = False
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class BusinessListResponse(BaseModel):
    total_items: int
    data: list[BusinessResponse]
