import uuid

from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_send_email_code_success():
    """Test sending 6-digit verification code to email."""
    response = client.post(
        "/api/v1/auth/email/send-code",
        json={"email": "resident@nearo.app"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "session_id" in data


def test_send_email_code_invalid_format():
    """Test validation failure on invalid email."""
    response = client.post(
        "/api/v1/auth/email/send-code",
        json={"email": "not-an-email"},
    )
    assert response.status_code == 422


def test_verify_email_code_success():
    """Test email code verification and JWT issuance."""
    response = client.post(
        "/api/v1/auth/email/verify-code",
        json={
            "session_id": str(uuid.uuid4()),
            "email": "demo@nearo.app",
            "code": "482910",
            "alias_name": "AyodhyaResident_04",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["alias_name"] == "AyodhyaResident_04"


def test_google_oauth_login():
    """Test Google OAuth / SSO one-tap sign-in and user sync."""
    response = client.post(
        "/api/v1/auth/oauth/google",
        json={
            "email": "google_user@nearo.app",
            "name": "Ayodhya Resident Google",
            "avatar_url": "https://lh3.googleusercontent.com/a/default-user",
            "clerk_user_id": "user_clerk_google_123",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == "google_user@nearo.app"


def test_legacy_send_otp_success():
    """Smoke test: sending an OTP to a valid mobile number (legacy support)."""
    response = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": "+919876543210"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "session_id" in data


def test_protected_route_without_token():
    """Test unauthorized access when token is missing."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
