import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class BusinessRegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=120, description="Business or Vendor Name")
    category: str = Field(
        ..., min_length=2, max_length=50, description="Category: healthcare, grocery, home_services, etc."
    )
    description: str | None = Field(None, max_length=500, description="Short business overview or services offered")
    whatsapp_number: str = Field(
        ..., pattern=r"^\+?[0-9]{10,15}$", description="WhatsApp contact number with country code"
    )
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)


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
