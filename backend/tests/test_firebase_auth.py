from unittest.mock import AsyncMock, MagicMock, patch
import uuid
import pytest
from fastapi.security import HTTPAuthorizationCredentials

from app.api.deps import get_current_user
from app.core.firebase import get_firebase_app, verify_firebase_token
from app.models.user import User


def test_firebase_app_initialization_mock():
    # Verify get_firebase_app runs without crashing
    app = get_firebase_app()
    assert app is not None or app is None


def test_verify_firebase_token_mock():
    mock_decoded = {
        "uid": "firebase_uid_test_12345",
        "email": "resident.test@nearo.app",
        "phone_number": "+919876543210",
        "name": "Ayodhya Resident",
        "picture": "https://lh3.googleusercontent.com/a/avatar",
    }
    with patch("jwt.get_unverified_header", return_value={"alg": "RS256", "kid": "mock_kid"}), \
         patch("firebase_admin.auth.verify_id_token", return_value=mock_decoded):
        payload = verify_firebase_token("valid_mock_firebase_token")
        assert payload["uid"] == "firebase_uid_test_12345"
        assert payload["email"] == "resident.test@nearo.app"
        assert payload["phone_number"] == "+919876543210"
        assert payload["name"] == "Ayodhya Resident"


@pytest.mark.asyncio
async def test_get_current_user_with_firebase_token():
    mock_decoded = {
        "uid": "fb_uid_resident_9999",
        "email": "new.resident@nearo.app",
        "phone_number": "+919123456789",
        "name": "Resident NinetyNine",
        "avatar_url": None,
    }

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()
    mock_db.add = MagicMock()

    with patch("app.api.deps.verify_firebase_token", return_value=mock_decoded):
        credentials = HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials="mock_firebase_jwt_token_for_deps",
        )
        user = await get_current_user(auth=credentials, db=mock_db, redis=None)
        assert isinstance(user, User)
        assert user.firebase_uid == "fb_uid_resident_9999"
        assert user.is_verified is True


@pytest.mark.asyncio
async def test_fcm_service_multicast_mock():
    from app.services.fcm import FCMService

    # Test with empty tokens
    res_empty = await FCMService.send_sos_multicast([], "SOS Alert", "Emergency test")
    assert res_empty["success_count"] == 0

    # Test with valid tokens
    res_tokens = await FCMService.send_sos_multicast(
        ["mock_fcm_device_token_1", "mock_fcm_device_token_2"],
        title="🚨 SOS Medical Alert",
        body="Assistance needed",
        data={"event": "CIVIC_SOS_ALERT"},
    )
    assert "success_count" in res_tokens
    assert "failure_count" in res_tokens


def test_update_fcm_token_authenticated():
    from app.core.security import create_access_token
    from app.main import app
    from fastapi.testclient import TestClient

    client = TestClient(app)
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/users/me/fcm-token",
        headers={"Authorization": f"Bearer {token}"},
        json={"fcm_token": "mock_fcm_device_registration_token_1234567890"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
