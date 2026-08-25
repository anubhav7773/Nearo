import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


# Email OTP Schemas
class EmailSendCodeRequest(BaseModel):
    email: str = Field(
        ...,
        pattern=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
        description="Resident email address",
    )


class EmailSendCodeResponse(BaseModel):
    success: bool = True
    message: str = "Verification code sent to email"
    session_id: str


class EmailVerifyCodeRequest(BaseModel):
    session_id: str
    email: str = Field(
        ...,
        pattern=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
        description="Resident email address",
    )
    code: str = Field(
        ..., min_length=4, max_length=6, description="6-digit verification code"
    )
    alias_name: str | None = Field(
        None, min_length=3, max_length=50, description="Neighborhood alias name"
    )


# Google OAuth Schema
class GoogleOAuthRequest(BaseModel):
    id_token: str | None = Field(
        None, description="Google / Clerk ID token or OAuth credential"
    )
    email: str = Field(
        ...,
        pattern=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
        description="Verified Google email",
    )
    name: str | None = Field(None, description="Display name from Google account")
    avatar_url: str | None = Field(None, description="Profile avatar URL")
    clerk_user_id: str | None = Field(
        None, description="Clerk User ID if authenticated via Clerk"
    )


class UserPublic(BaseModel):
    id: uuid.UUID
    alias_name: str
    tier: str
    is_verified: bool
    email: str | None = None
    avatar_url: str | None = None

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
    email: str | None = None
    avatar_url: str | None = None
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
    zone_name: str | None = None


# Profile Sync Schemas (Phase 1 Live Sync Pipeline)
class UserProfileSyncRequest(BaseModel):
    clerk_user_id: str | None = Field(None, description="Clerk User ID")
    email: str | None = Field(None, description="Resident email address")
    alias_name: str | None = Field(None, min_length=2, max_length=50, description="Display alias")
    avatar_url: str | None = Field(None, description="Profile avatar picture URL")
    preferred_radius_meters: int | None = Field(1500, ge=500, le=5000)


class UserProfileResponse(BaseModel):
    id: uuid.UUID
    clerk_user_id: str | None = None
    alias: str
    email: str | None = None
    avatar_url: str | None = None
    radius_km: float = 1.5
    tier: str = "free"
    is_verified: bool = True
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class UserRadiusUpdateRequest(BaseModel):
    radius_km: float = Field(
        ..., ge=0.5, le=5.0, description="Neighborhood radius preference in kilometers (0.5 - 5.0)"
    )


class UserDeleteResponse(BaseModel):
    status: str = "success"
    message: str = "All personal data erased permanently."


class FCMTokenSyncRequest(BaseModel):
    fcm_token: str = Field(..., min_length=10, description="Firebase Cloud Messaging device registration token")


class FCMTokenSyncResponse(BaseModel):
    success: bool = True
    message: str = "FCM token updated successfully"
