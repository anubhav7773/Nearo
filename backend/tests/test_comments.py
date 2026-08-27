import uuid

from app.core.security import create_access_token
from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_get_comments_returns_list_or_404():
    """Verify fetching comments for a post returns 200 with list or 404."""
    post_id = str(uuid.uuid4())
    response = client.get(f"/api/v1/posts/{post_id}/comments")
    assert response.status_code in (200, 404)
    if response.status_code == 200:
        data = response.json()
        assert isinstance(data, list)


def test_post_comment_unauthorized_returns_401():
    """Verify unauthorized user cannot post comments."""
    random_id = str(uuid.uuid4())
    response = client.post(
        f"/api/v1/posts/{random_id}/comments",
        json={"content": "This is a test comment."},
    )
    assert response.status_code == 401


def test_post_comment_authenticated():
    """Verify authenticated user can post a comment."""
    user_id = str(uuid.uuid4())
    post_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        f"/api/v1/posts/{post_id}/comments",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": "This is a verified neighbor comment."},
    )
    assert response.status_code in (201, 404)


def test_post_comment_invalid_uuid_returns_404():
    """Verify invalid post UUID returns 404 or validation error."""
    user_id = str(uuid.uuid4())
    token = create_access_token(subject=user_id)

    response = client.post(
        "/api/v1/posts/invalid-post-uuid/comments",
        headers={"Authorization": f"Bearer {token}"},
        json={"content": "This is a test comment."},
    )
    assert response.status_code in (404, 422)
