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


from sqlalchemy import text


async def init_spatial_db():
    """Ensure PostGIS extension exists, create st_asewkb(geography) compatibility shim,
    and migrate legacy geography columns to geometry(Point, 4326).
    """
    async with engine.begin() as conn:
        try:
            # 1. Enable PostGIS
            await conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))

            # 2. Compatibility shim: Define ST_AsEWKB for geography to eliminate asyncpg st_asewkb(geography) does not exist error permanently
            shim_sql = """
                CREATE OR REPLACE FUNCTION public.st_asewkb(geog geography)
                RETURNS bytea AS $$
                BEGIN
                    RETURN ST_AsEWKB(geog::geometry);
                END;
                $$ LANGUAGE plpgsql IMMUTABLE STRICT;
            """
            await conn.execute(text(shim_sql))

            # 3. Alter legacy geography columns to geometry(Point, 4326) across tables if they exist
            alter_sqls = [
                "ALTER TABLE public.posts ALTER COLUMN location TYPE geometry(Point, 4326) USING location::geometry;",
                "ALTER TABLE public.sos_events ALTER COLUMN location TYPE geometry(Point, 4326) USING location::geometry;",
                "ALTER TABLE public.sos_events ALTER COLUMN initial_location TYPE geometry(Point, 4326) USING initial_location::geometry;",
                "ALTER TABLE public.sos_events ALTER COLUMN current_location TYPE geometry(Point, 4326) USING current_location::geometry;",
                "ALTER TABLE public.user_locations ALTER COLUMN last_known_location TYPE geometry(Point, 4326) USING last_known_location::geometry;",
                "ALTER TABLE public.businesses ALTER COLUMN location TYPE geometry(Point, 4326) USING location::geometry;",
                "ALTER TABLE public.local_ads ALTER COLUMN target_center TYPE geometry(Point, 4326) USING target_center::geometry;",
            ]
            for alter_sql in alter_sqls:
                try:
                    await conn.execute(text(alter_sql))
                except Exception:
                    pass
        except Exception:
            pass


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
