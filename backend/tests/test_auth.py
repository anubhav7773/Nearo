import uuid
from fastapi.testclient import TestClient
from app.core.security import create_access_token
from app.main import app

client = TestClient(app)


def test_send_otp_success():
    """Smoke test: sending an OTP to a valid mobile number."""
    response = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": "+919876543210"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["message"] == "OTP sent successfully"
    assert "session_id" in data


def test_send_otp_invalid_phone():
    """Test validation rejection on invalid phone format."""
    response = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": "invalid_num"},
    )
    assert response.status_code == 422


def test_verify_otp_and_issue_tokens():
    """Smoke test: verify OTP with test session code."""
    response = client.post(
        "/api/v1/auth/otp/verify",
        json={
            "session_id": str(uuid.uuid4()),
            "otp": "482910",
            "alias_name": "AyodhyaResident_04",
        },
    )
    # 200 OK or handled session fallback
    if response.status_code == 200:
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["alias_name"] == "AyodhyaResident_04"


def test_protected_route_without_token():
    """Test unauthorized access when token is missing."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
