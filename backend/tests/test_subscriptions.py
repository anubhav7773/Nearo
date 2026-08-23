import uuid

from app.core.security import create_access_token
from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_get_admob_config():
    """Test retrieving AdMob app ID and ad units."""
    response = client.get("/api/v1/subscriptions/admob-config")
    assert response.status_code == 200
    data = response.json()
    assert "app_id" in data
    assert "banner_ad_unit_id" in data
    assert "native_ad_unit_id" in data


def test_get_subscription_tiers():
    """Test listing available subscription tiers."""
    response = client.get("/api/v1/subscriptions/tiers")
    assert response.status_code == 200
    data = response.json()
    assert "tiers" in data
    assert len(data["tiers"]) == 3


def test_google_play_purchase_verification_pro_resident():
    """Test Google Play purchase verification flow for Pro Resident subscription."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/subscriptions/verify-purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "purchase_token": "mock_purchase_token_12345",
            "product_id": "nearo_pro_resident_monthly",
            "package_name": "me.asiverticals.nearo",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["tier"] == "pro_resident"
    assert data["is_active"] is True
    assert "order_id" in data


def test_google_play_purchase_verification_business_pro():
    """Test Google Play purchase verification flow for Business Pro tier."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/subscriptions/verify-purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "purchase_token": "mock_purchase_token_biz_999",
            "product_id": "nearo_business_pro_monthly",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["tier"] == "business_pro"
    assert data["is_verified_merchant"] is True
