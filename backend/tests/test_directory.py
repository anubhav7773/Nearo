import uuid

from app.core.security import create_access_token
from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_get_directory_spatial_query():
    """Test GET /api/v1/directory returns list of verified nearby businesses."""
    response = client.get(
        "/api/v1/directory",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "radius_meters": 3000,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert "total_items" in data
    assert isinstance(data["data"], list)
    assert len(data["data"]) > 0
    first_biz = data["data"][0]
    assert "name" in first_biz
    assert "whatsapp_number" in first_biz
    assert "distance_text" in first_biz


def test_get_directory_category_filter():
    """Test GET /api/v1/directory with category filter."""
    response = client.get(
        "/api/v1/directory",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "category": "healthcare",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert isinstance(data["data"], list)


def test_register_business_authenticated():
    """Test vendor registration with coordinates and WhatsApp number."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/directory/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Ayodhya Solar Solutions",
            "category": "home_services",
            "description": "Rooftop solar panel installation and net metering consultancy.",
            "whatsapp_number": "+919876501234",
            "latitude": 26.7935,
            "longitude": 82.2010,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Ayodhya Solar Solutions"
    assert data["status"] == "active"
    assert "id" in data


def test_register_business_unauthorized():
    """Verify unauthorized business registration is rejected."""
    response = client.post(
        "/api/v1/directory/register",
        json={
            "name": "Unauthorized Vendor",
            "category": "grocery",
            "whatsapp_number": "+919876543210",
            "latitude": 26.7922,
            "longitude": 82.1998,
        },
    )
    assert response.status_code == 401


def test_register_business_with_lat_lng_aliases():
    """Verify business registration with lat and lng aliases."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/directory/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Awadh Dairy & Sweets",
            "category": "grocery",
            "description": "Pure milk and dairy products.",
            "whatsapp_number": "9876543210",
            "lat": 26.7935,
            "lng": 82.2010,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Awadh Dairy & Sweets"
    assert data["status"] == "active"
    assert "id" in data
