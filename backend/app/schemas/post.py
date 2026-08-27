import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.post import PostCategory
from app.schemas.ad import NativeAdResponse


def normalize_post_category(val: str | PostCategory | None) -> PostCategory:
    if not val:
        return PostCategory.GENERAL
    if isinstance(val, PostCategory):
        return val
    s = str(val).strip().lower().replace(" ", "_").replace("-", "_")
    if "civic" in s:
        return PostCategory.CIVIC_ISSUE
    if "alert" in s or "scam" in s:
        return PostCategory.ALERT
    if "help" in s:
        return PostCategory.HELP_NEEDED
    if "trade" in s or "buy" in s or "sell" in s:
        return PostCategory.TRADE
    if "general" in s:
        return PostCategory.GENERAL
    try:
        return PostCategory(s)
    except ValueError:
        return PostCategory.GENERAL


class PostCreate(BaseModel):
    category: str | PostCategory = PostCategory.GENERAL
    title: str | None = Field(None, max_length=150)
    content: str | None = Field(None, min_length=1)
    body: str | None = Field(None, min_length=1, description="Alias for content")
    latitude: float | None = Field(None, ge=-90.0, le=90.0)
    longitude: float | None = Field(None, ge=-180.0, le=180.0)
    lat: float | None = Field(None, ge=-90.0, le=90.0, description="Alias for latitude")
    lng: float | None = Field(None, ge=-180.0, le=180.0, description="Alias for longitude")
    media_urls: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_fields(self):
        self.category = normalize_post_category(self.category)
        if not self.content and not self.body:
            raise ValueError("Either 'content' or 'body' must be provided.")
        if not self.content and self.body:
            self.content = self.body
        if self.latitude is None and self.lat is not None:
            self.latitude = self.lat
        if self.longitude is None and self.lng is not None:
            self.longitude = self.lng
        if self.latitude is None or self.longitude is None:
            raise ValueError("Coordinates ('latitude'/'longitude' or 'lat'/'lng') are required.")
        return self


class PostCreateResponse(BaseModel):
    id: uuid.UUID
    status: str = "published"
    created_at: datetime | None = None
    title: str | None = None
    content: str | None = None
    category: str | None = None
    author_alias: str | None = "Citizen"
    author_tier: str | None = "free"
    author_avatar_url: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    distance_meters: int | None = 0
    distance_text: str | None = "Just now · Here"
    media_urls: list[str] = Field(default_factory=list)


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


class CommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)


class CommentResponse(BaseModel):
    id: uuid.UUID
    post_id: uuid.UUID
    author_id: uuid.UUID
    author_alias: str = "Citizen"
    author_avatar_url: str | None = None
    author_tier: str = "free"
    content: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
