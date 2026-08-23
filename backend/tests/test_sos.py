import uuid
from app.core.security import create_access_token
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


def test_sos_trigger_authenticated():
    """Verify authenticated SOS trigger endpoint."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/sos/trigger",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "emergency_type": "medical",
            "description": "Medical assistance needed near Sector 4",
            "latitude": 26.7922,
            "longitude": 82.1998,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "active"
    assert "sos_id" in data
    assert data["broadcast_radius_meters"] == 1500


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
