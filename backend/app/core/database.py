from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# Supabase Transaction Pooler (port 6543) requires disabling statement cache in asyncpg
connect_args: dict[str, int] = {}
if "pooler.supabase.com" in settings.async_database_url or ":6543" in settings.async_database_url:
    connect_args = {
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0,
    }

# SQLAlchemy 2.0 Async Engine configuration
engine = create_async_engine(
    settings.async_database_url,
    echo=(settings.ENVIRONMENT == "development"),
    future=True,
    pool_pre_ping=True,
    pool_recycle=300,
    pool_timeout=30,
    pool_size=10,
    max_overflow=20,
    connect_args=connect_args,
)

# Async session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    """Base declarative class for all SQLAlchemy ORM models."""


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency provider yielding an asynchronous SQLAlchemy database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
