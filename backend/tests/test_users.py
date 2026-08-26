import uuid

from app.core.security import create_access_token
from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_user_profile_sync_unauthenticated_upsert():
    """Test user profile sync and auto-provisioning from Clerk metadata."""
    response = client.post(
        "/api/v1/users/sync",
        json={
            "clerk_user_id": "user_clerk_phase1_sync",
            "email": "sync_resident@nearo.app",
            "alias_name": "AyodhyaSyncResident",
            "avatar_url": "https://lh3.googleusercontent.com/avatar1.png",
            "preferred_radius_meters": 2000,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["alias"] == "AyodhyaSyncResident"
    assert data["email"] == "sync_resident@nearo.app"
    assert data["clerk_user_id"] == "user_clerk_phase1_sync"
    assert "id" in data
    assert data["tier"] == "free"


def test_user_profile_sync_with_token():
    """Test profile sync using authenticated Bearer token."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/users/sync",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "alias_name": "UpdatedTokenResident",
            "avatar_url": "https://lh3.googleusercontent.com/avatar2.png",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["alias"] == "UpdatedTokenResident"
    assert "id" in data


def test_get_users_me_endpoint():
    """Test GET /api/v1/users/me returns authenticated resident profile."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert "alias" in data
    assert "radius_km" in data


def test_get_users_me_unauthorized():
    """Verify unauthorized request to /users/me is rejected."""
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401


def test_patch_user_radius_valid():
    """Test updating user radius within allowed boundaries (0.5km - 5.0km)."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.patch(
        "/api/v1/users/me/radius",
        headers={"Authorization": f"Bearer {token}"},
        json={"radius_km": 2.5},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["radius_km"] == 2.5


def test_patch_user_radius_out_of_bounds():
    """Test radius update rejection for values < 0.5km or > 5.0km."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    # Test > 5.0 km
    response_large = client.patch(
        "/api/v1/users/me/radius",
        headers={"Authorization": f"Bearer {token}"},
        json={"radius_km": 15.0},
    )
    assert response_large.status_code == 422

    # Test < 0.5 km
    response_small = client.patch(
        "/api/v1/users/me/radius",
        headers={"Authorization": f"Bearer {token}"},
        json={"radius_km": 0.1},
    )
    assert response_small.status_code == 422


def test_delete_user_account_cascade():
    """Test hard account deletion under DPDP privacy regulations."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.delete(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("deleted", "success")
    assert "erased" in data["message"].lower()
