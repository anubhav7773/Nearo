import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class OTPSendRequest(BaseModel):
    phone_number: str = Field(..., pattern=r"^\+?[1-9]\d{7,14}$", description="E.164 phone number format")


class OTPSendResponse(BaseModel):
    success: bool = True
    message: str = "OTP sent successfully"
    session_id: str


class OTPVerifyRequest(BaseModel):
    session_id: str
    otp: str = Field(..., min_length=4, max_length=6, description="Received OTP code")
    alias_name: Optional[str] = Field(None, min_length=3, max_length=50, description="Neighborhood alias name")


class UserPublic(BaseModel):
    id: uuid.UUID
    alias_name: str
    tier: str
    is_verified: bool

    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserPublic


class UserResponse(BaseModel):
    id: uuid.UUID
    alias_name: str
    role: str
    tier: str
    is_verified: bool
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserLocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    pincode: str = Field(..., min_length=4, max_length=10)
    preferred_radius_meters: int = Field(default=1500, ge=500, le=5000)


class UserLocationResponse(BaseModel):
    success: bool = True
    active_radius_meters: int = 1500
    zone_name: Optional[str] = None
