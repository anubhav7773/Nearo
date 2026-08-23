import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from app.models.user import SubscriptionTier


class NativeAdResponse(BaseModel):
    type: str = "native_ad"
    id: str
    business_name: str
    tagline: Optional[str] = None
    cta_title: str = "Contact on WhatsApp"
    whatsapp_url: Optional[str] = None
    distance_meters: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class SubscriptionCreateOrder(BaseModel):
    tier: SubscriptionTier = SubscriptionTier.PRO_RESIDENT
    duration_months: int = Field(default=1, ge=1, le=12)


class SubscriptionResponse(BaseModel):
    order_id: str
    amount_inr: float
    currency: str = "INR"
    tier: str
    starts_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None


class GooglePlayPurchaseVerifyRequest(BaseModel):
    purchase_token: str = Field(..., description="Google Play In-App Billing Purchase Token")
    product_id: str = Field(..., description="Product SKU / Subscription ID")
    package_name: Optional[str] = Field(None, description="App package name override")


class GooglePlayPurchaseVerifyResponse(BaseModel):
    success: bool
    message: str
    tier: str
    order_id: Optional[str] = None
    is_active: bool = True
    is_verified_merchant: bool = False
    starts_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None


class AdMobConfigResponse(BaseModel):
    app_id: str
    banner_ad_unit_id: str
    native_ad_unit_id: str
