import enum
import uuid

from geoalchemy2 import Geometry
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class PostCategory(str, enum.Enum):
    GENERAL = "general"
    ALERT = "alert"
    CIVIC_ISSUE = "civic_issue"
    HELP_NEEDED = "help_needed"
    TRADE = "trade"


class Post(Base):
    __tablename__ = "posts"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("uuid_generate_v4()"),
    )
    author_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    category = Column(
        Enum(
            PostCategory,
            name="post_category",
            native_enum=True,
            values_callable=lambda obj: [e.value for e in obj],
        ),
        default=PostCategory.GENERAL,
        nullable=False,
        index=True,
    )
    title = Column(String(150), nullable=True)
    content = Column(Text, nullable=False)
    media_urls = Column(ARRAY(Text), server_default="{}", default=list, nullable=False)
    location = Column(
        Geometry(geometry_type="POINT", srid=4326, spatial_index=True),
        nullable=False,
    )
    is_pinned = Column(Boolean, default=False, nullable=False)
    upvotes_count = Column(Integer, default=0, nullable=False)
    comments_count = Column(Integer, default=0, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    author = relationship("User", back_populates="posts")

    __table_args__ = (Index("idx_posts_created_at", created_at.desc()),)


class PostUpvote(Base):
    __tablename__ = "post_upvotes"

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    post_id = Column(
        UUID(as_uuid=True),
        ForeignKey("posts.id", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    __table_args__ = (Index("idx_post_upvotes_post_user", post_id, user_id),)
