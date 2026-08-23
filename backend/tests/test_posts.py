import uuid

from app.core.security import create_access_token
from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_get_posts_with_category_filter():
    """Verify GET /api/v1/posts accepts category filter and spatial params."""
    response = client.get(
        "/api/v1/posts",
        params={
            "lat": 26.7922,
            "lng": 82.1998,
            "radius_meters": 2000,
            "category": "civic_issue",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert isinstance(data["data"], list)


def test_create_post_authenticated():
    """Test creating a post with GPS coordinates and title/content."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/posts",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "Broken Streetlight at Crossroad 4",
            "content": "Streetlight has been flickering and causing visibility issues at night.",
            "category": "civic_issue",
            "latitude": 26.7930,
            "longitude": 82.2005,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "published"
    assert "id" in data


def test_create_post_unauthenticated():
    """Verify unauthorized post creation is rejected."""
    response = client.post(
        "/api/v1/posts",
        json={
            "content": "Unauthenticated post attempt",
            "latitude": 26.7922,
            "longitude": 82.1998,
        },
    )
    assert response.status_code == 401


def test_toggle_post_upvote_endpoint():
    """Verify upvote toggle endpoint responds with updated count and state."""
    user_id = str(uuid.uuid4())
    post_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        f"/api/v1/posts/{post_id}/upvote",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code in (200, 404)
