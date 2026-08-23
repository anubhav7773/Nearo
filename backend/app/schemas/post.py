import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.post import PostCategory
from app.schemas.ad import NativeAdResponse


class PostCreate(BaseModel):
    category: PostCategory = PostCategory.GENERAL
    title: str | None = Field(None, max_length=150)
    content: str | None = Field(None, min_length=1)
    body: str | None = Field(None, min_length=1, description="Alias for content")
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    media_urls: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_content_or_body(self):
        if not self.content and not self.body:
            raise ValueError("Either 'content' or 'body' must be provided.")
        if not self.content and self.body:
            self.content = self.body
        return self


class PostCreateResponse(BaseModel):
    id: uuid.UUID
    status: str = "published"
    created_at: datetime | None = None


class PostResponse(BaseModel):
    type: str = "community_post"
    id: uuid.UUID
    author_alias: str
    author_tier: str = "free"
    author_avatar_url: str | None = None
    category: str
    title: str | None = None
    content: str
    distance_meters: int | None = None
    distance_text: str | None = None
    upvotes: int = 0
    has_upvoted: bool = False
    comments_count: int = 0
    latitude: float | None = None
    longitude: float | None = None
    media_urls: list[str] = Field(default_factory=list)
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PostUpvoteResponse(BaseModel):
    success: bool = True
    post_id: uuid.UUID
    upvotes_count: int
    has_upvoted: bool


class FeedResponse(BaseModel):
    page: int
    total_items: int
    data: list[PostResponse | NativeAdResponse]
