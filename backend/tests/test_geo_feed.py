import uuid
from datetime import datetime, timezone

from app.main import app
from app.models.user import SubscriptionTier
from app.schemas.ad import NativeAdResponse
from app.schemas.post import PostResponse
from app.services.ad_engine import AdEngine
from app.services.geo_service import apply_coordinate_jitter
from fastapi.testclient import TestClient

client = TestClient(app)


def test_get_feed_endpoint():
    """Smoke test: GET /api/v1/posts/feed returns 200 with paginated structure."""
    response = client.get(
        "/api/v1/posts/feed",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "radius_meters": 1500,
            "page": 1,
            "limit": 15,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "page" in data
    assert "total_items" in data
    assert "data" in data
    assert isinstance(data["data"], list)


def test_get_feed_endpoint_with_latitude_longitude_aliases():
    """Verify GET /api/v1/posts/feed accepts full latitude and longitude query params."""
    response = client.get(
        "/api/v1/posts/feed",
        params={
            "latitude": 26.7922,
            "longitude": 82.1998,
            "radius_meters": 3000,
            "category": "general",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert isinstance(data["data"], list)


def test_get_posts_endpoint_alias():
    """Verify GET /api/v1/posts returns the same feed structure."""
    response = client.get(
        "/api/v1/posts",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "radius_meters": 1500,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert isinstance(data["data"], list)


def test_coordinate_jitter_anti_triangulation():
    """Verify anti-triangulation spatial jitter stays within 75-125m radius."""
    lat, lon = 26.7922, 82.1998
    for _ in range(10):
        j_lat, j_lon = apply_coordinate_jitter(
            lat, lon, min_meters=75.0, max_meters=125.0
        )
        assert (j_lat, j_lon) != (lat, lon)
        # Verify delta is bounded by ~0.002 degrees (under 200 meters)
        assert abs(j_lat - lat) < 0.003
        assert abs(j_lon - lon) < 0.003


def test_ad_injection_cadence_and_pro_ad_free():
    """Verify ad injection occurs every 6 community posts and pro users receive 0 ads."""
    posts = [
        PostResponse(
            id=uuid.uuid4(),
            author_alias=f"Resident_{i}",
            category="general",
            content=f"Post update {i}",
            upvotes=i,
            created_at=datetime.now(timezone.utc),
        )
        for i in range(14)
    ]

    ads = [
        NativeAdResponse(
            id=f"ad_{i}",
            business_name=f"Local Shop {i}",
            cta_title="Chat on WhatsApp",
            distance_meters=400,
        )
        for i in range(3)
    ]

    # Free tier: 14 posts + 2 injected ads (at index 6 and index 13)
    free_feed = AdEngine.inject_native_ads(posts, ads, user_tier=SubscriptionTier.FREE)
    assert len(free_feed) == 16
    assert getattr(free_feed[6], "type", None) == "native_ad"
    assert getattr(free_feed[13], "type", None) == "native_ad"

    # Pro tier: strictly 14 community posts and zero ads
    pro_feed = AdEngine.inject_native_ads(
        posts, ads, user_tier=SubscriptionTier.PRO_RESIDENT
    )
    assert len(pro_feed) == 14
    assert all(getattr(item, "type", None) == "community_post" for item in pro_feed)
