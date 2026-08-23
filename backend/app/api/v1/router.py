from fastapi import APIRouter
from app.api.v1.endpoints import (
    ads,
    auth,
    feed,
    location,
    sos,
    subscriptions,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(feed.router, prefix="/posts", tags=["Feed & Posts"])
api_router.include_router(location.router, prefix="/location", tags=["Location & Geofencing"])
api_router.include_router(sos.router, prefix="/sos", tags=["Civic SOS & Dispatch"])
api_router.include_router(ads.router, prefix="/ads", tags=["Hyperlocal Native Ads"])
api_router.include_router(subscriptions.router, prefix="/subscriptions", tags=["Subscriptions & Monetization"])
