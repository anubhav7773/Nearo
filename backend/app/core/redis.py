import asyncio
import logging
import time
from collections.abc import AsyncGenerator

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)

redis_pool: aioredis.Redis | None = None
_redis_disabled: bool = False

# In-memory fallbacks when Redis is not available
_in_memory_rate_limits: dict[str, tuple[int, float]] = {}
_in_memory_kv: dict[str, tuple[str, float]] = {}


async def init_redis_pool() -> aioredis.Redis | None:
    """Initialize the asynchronous Redis connection pool gracefully."""
    global redis_pool, _redis_disabled

    if not settings.REDIS_URL or settings.REDIS_URL.strip() == "":
        logger.info("REDIS_URL not configured. Running with in-memory cache/rate-limiting.")
        _redis_disabled = True
        redis_pool = None
        return None

    try:
        client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=0.4,
            socket_timeout=0.4,
        )
        await asyncio.wait_for(client.ping(), timeout=0.4)
        redis_pool = client
        _redis_disabled = False
        logger.info("Connected to Redis broker successfully.")
        return redis_pool
    except (OSError, ConnectionRefusedError, asyncio.TimeoutError, Exception) as exc:
        logger.warning(
            "Redis connection unavailable (%s). Falling back gracefully to in-memory store.",
            str(exc),
        )
        redis_pool = None
        _redis_disabled = True
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
    if _redis_disabled or redis_pool is None:
        yield None
        return

    try:
        yield redis_pool
    except Exception:
        yield None


async def check_rate_limit(
    redis: aioredis.Redis | None,
    key: str,
    max_requests: int,
    window_seconds: int,
) -> bool:
    """Token-bucket / fixed-window rate limiter using Redis with in-memory fallback.

    Returns:
        bool: True if request is allowed, False if rate limit is exceeded.
    """
    if redis is not None:
        try:
            current_count = await asyncio.wait_for(redis.incr(key), timeout=0.4)
            if current_count == 1:
                await asyncio.wait_for(redis.expire(key, window_seconds), timeout=0.4)
            return current_count <= max_requests
        except Exception:
            pass  # Fall through to in-memory rate limiting

    # In-memory rate limiting fallback
    now = time.time()
    if key in _in_memory_rate_limits:
        count, expires_at = _in_memory_rate_limits[key]
        if now > expires_at:
            _in_memory_rate_limits[key] = (1, now + window_seconds)
            return True
        else:
            _in_memory_rate_limits[key] = (count + 1, expires_at)
            return (count + 1) <= max_requests
    else:
        _in_memory_rate_limits[key] = (1, now + window_seconds)
        return True


def get_in_memory_value(key: str) -> str | None:
    """Get value from in-memory fallback KV store."""
    now = time.time()
    if key in _in_memory_kv:
        val, expires_at = _in_memory_kv[key]
        if now <= expires_at:
            return val
        else:
            del _in_memory_kv[key]
    return None


def set_in_memory_value(key: str, value: str, ttl_seconds: int = 300) -> None:
    """Set value in in-memory fallback KV store with TTL."""
    now = time.time()
    _in_memory_kv[key] = (value, now + ttl_seconds)


def delete_in_memory_value(key: str) -> None:
    """Delete key from in-memory fallback KV store."""
    _in_memory_kv.pop(key, None)
