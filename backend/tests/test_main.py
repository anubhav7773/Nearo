from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_root_endpoint_get_and_head():
    """Test root / endpoint for GET and HEAD requests for UptimeRobot monitoring."""
    # GET request
    response_get = client.get("/")
    assert response_get.status_code == 200
    data = response_get.json()
    assert data["status"] == "healthy"
    assert "service" in data

    # HEAD request (used by UptimeRobot free tier)
    response_head = client.head("/")
    assert response_head.status_code == 200


def test_health_endpoint_get_and_head():
    """Test /health and /api/v1/health endpoints for GET and HEAD requests."""
    # /health
    response_health_get = client.get("/health")
    assert response_health_get.status_code == 200
    assert response_health_get.json()["status"] == "healthy"

    response_health_head = client.head("/health")
    assert response_health_head.status_code == 200

    # /api/v1/health
    response_v1_get = client.get("/api/v1/health")
    assert response_v1_get.status_code == 200
    assert response_v1_get.json()["status"] == "healthy"

    response_v1_head = client.head("/api/v1/health")
    assert response_v1_head.status_code == 200


def test_docs_and_openapi_endpoints():
    """Test OpenAPI schema and Swagger UI documentation endpoints."""
    response_openapi = client.get("/openapi.json")
    assert response_openapi.status_code == 200
    assert "openapi" in response_openapi.json()

    response_docs = client.get("/docs")
    assert response_docs.status_code == 200

    response_docs_alias = client.get("/api/v1/docs", follow_redirects=True)
    assert response_docs_alias.status_code == 200
