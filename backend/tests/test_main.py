from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_root_endpoint():
    """Test root / endpoint for uptime monitoring."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "service" in data


def test_health_endpoint():
    """Test /health and /api/v1/health endpoints."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

    response_v1 = client.get("/api/v1/health")
    assert response_v1.status_code == 200
    assert response_v1.json()["status"] == "healthy"


def test_docs_and_openapi_endpoints():
    """Test OpenAPI schema and Swagger UI documentation endpoints."""
    response_openapi = client.get("/openapi.json")
    assert response_openapi.status_code == 200
    assert "openapi" in response_openapi.json()

    response_docs = client.get("/docs")
    assert response_docs.status_code == 200

    response_docs_alias = client.get("/api/v1/docs", follow_redirects=True)
    assert response_docs_alias.status_code == 200
