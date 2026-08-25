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


def test_legacy_otp_endpoints_are_purged():
    """Phone/SMS OTP flow is permanently discontinued — routes must not exist."""
    send_response = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": "+919876543210"},
    )
    assert send_response.status_code == 404

    verify_response = client.post(
        "/api/v1/auth/otp/verify",
        json={"session_id": "dummy-session", "otp": "482910"},
    )
    assert verify_response.status_code == 404


def test_otp_routes_absent_from_openapi_schema():
    """OpenAPI contract must no longer advertise the SMS OTP endpoints."""
    paths = client.get("/openapi.json").json()["paths"]
    assert "/api/v1/auth/otp/send" not in paths
    assert "/api/v1/auth/otp/verify" not in paths
    assert "/api/v1/auth/oauth/google" in paths


def test_protected_route_without_token():
    """Test unauthorized access when token is missing."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401


def test_me_returns_profile_for_authenticated_resident():
    """GET /auth/me resolves the bearer token into a full resident profile."""
    from app.core.security import create_access_token

    token = create_access_token(subject=str(uuid.uuid4()))
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "resident"
    assert data["tier"] == "free"
    assert data["is_active"] is True
    assert data["created_at"] is not None


def test_me_rejects_malformed_bearer_token():
    """A syntactically invalid token must not resolve to a resident."""
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer not-a-real-token"},
    )
    assert response.status_code == 401
