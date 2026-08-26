from fastapi import APIRouter

from app.api.v1.endpoints import (
    ads,
    auth,
    directory,
    feed,
    location,
    posts,
    sos,
    subscriptions,
    users,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(users.router, prefix="/users", tags=["Users & Profiles"])
api_router.include_router(posts.router, prefix="/posts", tags=["Feed & Posts"])
api_router.include_router(directory.router, prefix="/directory", tags=["Business Directory"])
api_router.include_router(
    location.router, prefix="/location", tags=["Location & Geofencing"]
)
api_router.include_router(sos.router, prefix="/sos", tags=["Civic SOS & Dispatch"])
api_router.include_router(ads.router, prefix="/ads", tags=["Hyperlocal Native Ads"])
api_router.include_router(
    subscriptions.router, prefix="/subscriptions", tags=["Subscriptions & Monetization"]
)
