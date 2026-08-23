from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_sos_broadcast_requires_auth():
    """Verify unauthorized SOS broadcast requests are rejected with 401."""
    response = client.post(
        "/api/v1/sos/broadcast",
        json={
            "emergency_type": "security",
            "description": "Suspicious activity reported",
            "latitude": 26.7922,
            "longitude": 82.1998,
        },
    )
    assert response.status_code == 401


def test_get_active_sos_emergencies():
    """Smoke test: GET /api/v1/sos/active returns active emergencies within radius."""
    response = client.get(
        "/api/v1/sos/active",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "radius_meters": 3000,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)


def test_subscription_tiers_endpoint():
    """Verify subscription tiers list returns Free and Pro pricing."""
    response = client.get("/api/v1/subscriptions/tiers")
    assert response.status_code == 200
    data = response.json()
    assert "tiers" in data
    tier_names = [t["tier"] for t in data["tiers"]]
    assert "free" in tier_names
    assert "pro_resident" in tier_names
