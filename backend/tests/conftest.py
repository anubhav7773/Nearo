import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from app.core.database import get_db
from app.core.redis import get_redis
from app.main import app
from app.models.user import SubscriptionTier, User, UserRole


@pytest.fixture(autouse=True)
def override_dependencies():
    """Override database and redis dependencies during automated test execution."""
    mock_db = AsyncMock()

    # Mock user for auth lookups
    test_user = User(
        id=uuid.UUID("c3b88b72-749e-4e4a-b5e2-63a12903b412"),
        phone_number="+919876543210",
        alias_name="AyodhyaResident_04",
        role=UserRole.RESIDENT,
        tier=SubscriptionTier.FREE,
        is_verified=True,
        is_active=True,
        created_at=datetime.now(timezone.utc),
    )

    # Mock execute result
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = test_user
    mock_result.scalar_one.return_value = 0
    mock_result.all.return_value = []
    mock_result.first.return_value = None
    mock_db.execute.return_value = mock_result
    mock_db.commit.return_value = None
    mock_db.refresh.return_value = None
    mock_db.add = MagicMock()
    mock_db.delete = AsyncMock()

    async def _override_get_db():
        yield mock_db

    async def _override_get_redis():
        yield None

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_redis] = _override_get_redis

    yield

    app.dependency_overrides.clear()
