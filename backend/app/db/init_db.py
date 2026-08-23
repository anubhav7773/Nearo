import asyncio
import logging
from pathlib import Path

from sqlalchemy import text

# Ensure all models are imported so Base.metadata knows about all tables
import app.models  # noqa: F401
from app.core.config import settings
from app.core.database import Base, engine

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nearo.db_init")

# Schema initialization script path
SCHEMA_SQL_PATH = (
    Path(__file__).resolve().parents[3] / "docs" / "02_DATABASE_SCHEMA.sql"
)


async def check_database_connection() -> bool:
    """Verify database connectivity with a lightweight ping query."""
    try:
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT 1"))
            return result.scalar() == 1
    except Exception as e:
        logger.error(f"Database connection check failed: {e}")
        return False


async def init_db() -> None:
    """Initialize PostgreSQL extensions, enum types, tables, and PostGIS spatial indexes."""
    logger.info("Starting Nearo database initialization...")

    is_connected = await check_database_connection()
    if not is_connected:
        logger.warning(
            f"Could not connect to PostgreSQL at {settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}. "
            "Please ensure database server is running."
        )
        return

    logger.info("Connected to PostgreSQL successfully.")

    async with engine.begin() as conn:
        # 1. Enable required PostgreSQL & PostGIS extensions
        logger.info("Enabling PostGIS and UUID extensions...")
        await conn.execute(text('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'))
        await conn.execute(text('CREATE EXTENSION IF NOT EXISTS "postgis";'))

        # 2. Check and create enum types idempotently
        enum_definitions = [
            ("user_role", "('resident', 'moderator', 'business', 'admin')"),
            ("subscription_tier", "('free', 'pro_resident', 'business_pro')"),
            (
                "post_category",
                "('general', 'alert', 'civic_issue', 'help_needed', 'trade')",
            ),
            ("sos_status", "('active', 'resolved', 'false_alarm')"),
            ("ad_type", "('in_feed_card', 'directory_top')"),
        ]

        for enum_name, enum_values in enum_definitions:
            check_sql = text(
                f"SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = '{enum_name}');"
            )
            type_exists = (await conn.execute(check_sql)).scalar()
            if not type_exists:
                logger.info(f"Creating enum type: {enum_name}")
                await conn.execute(
                    text(f"CREATE TYPE {enum_name} AS ENUM {enum_values};")
                )

        # 3. Create all tables via SQLAlchemy declarative metadata
        logger.info("Creating declarative ORM tables...")
        await conn.run_sync(Base.metadata.create_all)

        # 4. Create explicit spatial GIST indexes if not already present
        spatial_indexes = [
            ("idx_user_locations_geom", "user_locations", "last_known_location"),
            ("idx_posts_geom", "posts", "location"),
            ("idx_sos_events_geom", "sos_events", "current_location"),
            ("idx_local_ads_geom", "local_ads", "target_center"),
        ]

        for idx_name, table_name, col_name in spatial_indexes:
            index_check_sql = text(
                "SELECT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace "
                f"WHERE c.relname = '{idx_name}');"
            )
            idx_exists = (await conn.execute(index_check_sql)).scalar()
            if not idx_exists:
                logger.info(
                    f"Creating spatial GIST index: {idx_name} on {table_name}({col_name})"
                )
                await conn.execute(
                    text(
                        f"CREATE INDEX IF NOT EXISTS {idx_name} ON {table_name} USING GIST({col_name});"
                    )
                )

    logger.info("Nearo database initialization completed successfully.")


if __name__ == "__main__":
    asyncio.run(init_db())
