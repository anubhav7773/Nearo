import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.post import PostCategory
from app.schemas.ad import NativeAdResponse


class PostCreate(BaseModel):
    category: PostCategory = PostCategory.GENERAL
    title: str | None = Field(None, max_length=150)
    content: str = Field(..., min_length=1)
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    media_urls: list[str] = Field(default_factory=list)


class PostCreateResponse(BaseModel):
    id: uuid.UUID
    status: str = "published"
    created_at: datetime


class PostResponse(BaseModel):
    type: str = "community_post"
    id: uuid.UUID
    author_alias: str
    category: str
    title: str | None = None
    content: str
    distance_meters: int | None = None
    upvotes: int = 0
    comments_count: int = 0
    latitude: float | None = None
    longitude: float | None = None
    media_urls: list[str] = Field(default_factory=list)
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FeedResponse(BaseModel):
    page: int
    total_items: int
    data: list[PostResponse | NativeAdResponse]
