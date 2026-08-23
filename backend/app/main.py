from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.redis import close_redis_pool, init_redis_pool


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Lifespan Startup: initialize Redis connection pool
    await init_redis_pool()
    yield
    # Lifespan Shutdown: gracefully close Redis connections
    await close_redis_pool()


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Privacy-first, hyperlocal community & civic SOS platform backend gateway.",
    version="1.0.0",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

# Configure CORS origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=[str(origin).rstrip("/") for origin in settings.BACKEND_CORS_ORIGINS] if settings.BACKEND_CORS_ORIGINS else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Exception Handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "error": "Validation Error",
            "details": exc.errors(),
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": exc.detail,
        },
        headers=exc.headers,
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": "Internal Server Error",
            "message": str(exc) if settings.ENVIRONMENT == "development" else "An unexpected error occurred.",
        },
    )


# Attach Version 1 API Router
app.include_router(api_router, prefix=settings.API_V1_STR)


# Health Check Endpoints
@app.get("/health", tags=["Health"])
@app.get(f"{settings.API_V1_STR}/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "subdomain": settings.SUBDOMAIN,
        "environment": settings.ENVIRONMENT,
        "version": "1.0.0",
    }
