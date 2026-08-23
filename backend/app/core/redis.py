import asyncio
from collections.abc import AsyncGenerator

import redis.asyncio as aioredis

from app.core.config import settings

redis_pool: aioredis.Redis | None = None


async def init_redis_pool() -> aioredis.Redis | None:
    """Initialize the asynchronous Redis connection pool."""
    global redis_pool
    try:
        client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=0.5,
            socket_timeout=0.5,
        )
        await asyncio.wait_for(client.ping(), timeout=0.5)
        redis_pool = client
        return redis_pool
    except Exception:
        redis_pool = None
        return None


async def close_redis_pool() -> None:
    """Close the Redis connection pool on application shutdown."""
    global redis_pool
    if redis_pool:
        try:
            await redis_pool.close()
        except Exception:
            pass
        redis_pool = None


async def get_redis() -> AsyncGenerator[aioredis.Redis | None, None]:
    """FastAPI dependency provider yielding the Redis client if online, else None."""
    global redis_pool
    if redis_pool is not None:
        try:
            await asyncio.wait_for(redis_pool.ping(), timeout=0.3)
            yield redis_pool
            return
        except Exception:
            redis_pool = None

    # Try connecting once with short timeout
    try:
        client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=0.3,
            socket_timeout=0.3,
        )
        await asyncio.wait_for(client.ping(), timeout=0.3)
        redis_pool = client
        yield redis_pool
    except Exception:
        yield None


async def check_rate_limit(
    redis: aioredis.Redis | None,
    key: str,
    max_requests: int,
    window_seconds: int,
) -> bool:
    """Token-bucket / fixed-window rate limiter using Redis.

    Returns:
        bool: True if request is allowed, False if rate limit is exceeded.
    """
    if redis is None:
        return True  # Fallback to allowing request if cache broker is offline

    try:
        current_count = await asyncio.wait_for(redis.incr(key), timeout=0.5)
        if current_count == 1:
            await asyncio.wait_for(redis.expire(key, window_seconds), timeout=0.5)
        return current_count <= max_requests
    except Exception:
        return True
