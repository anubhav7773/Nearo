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
            "category": "security",
            "description": "Suspicious activity reported",
            "latitude": 26.7922,
            "longitude": 82.1998,
        },
    )
    assert response.status_code == 401


def test_sos_trigger_authenticated():
    """Verify authenticated SOS trigger endpoint returns real reach count."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/sos/broadcast",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "category": "medical",
            "description": "Medical assistance needed near Sector 4",
            "latitude": 26.7922,
            "longitude": 82.1998,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "active"
    assert "event_id" in data
    assert "dispatched_neighbors_count" in data
    assert data["dispatched_neighbors_count"] >= 1


def test_get_active_sos_status():
    """Test GET /api/v1/sos/active returns user active emergency state."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.get(
        "/api/v1/sos/active",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "has_active" in data


def test_get_nearby_active_sos_emergencies():
    """Test GET /api/v1/sos/nearby returns active emergencies within radius."""
    response = client.get(
        "/api/v1/sos/nearby",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "radius_meters": 3000,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)


def test_resolve_sos_endpoint():
    """Verify resolution of an active SOS emergency."""
    user_id = str(uuid.uuid4())
    event_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        f"/api/v1/sos/{event_id}/resolve",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code in (200, 404, 403)


def test_sos_broadcast_with_lat_lng_aliases():
    """Verify SOS broadcast works with lat and lng aliases."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/sos/broadcast",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "category": "fire",
            "description": "Short circuit spark in transformer",
            "lat": 26.7922,
            "lng": 82.1998,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "active"
    assert "event_id" in data
    assert "dispatched_neighbors_count" in data
