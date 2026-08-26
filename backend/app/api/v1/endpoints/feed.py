"""Feed and Posts API router module."""

from app.api.v1.endpoints.posts import create_post, get_nearby_posts, router, toggle_post_upvote

__all__ = ["router", "get_nearby_posts", "create_post", "toggle_post_upvote"]
