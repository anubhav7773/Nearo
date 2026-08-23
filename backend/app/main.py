from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse

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
    openapi_url="/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)


# Root Health & Uptime Endpoints (explicitly handles GET & HEAD at top level for UptimeRobot / Render pingers)
@app.api_route("/", methods=["GET", "HEAD"], include_in_schema=True)
async def root_ping():
    return {
        "status": "healthy",
        "service": "Nearo Backend API",
        "version": "1.0.0",
    }


@app.api_route("/health", methods=["GET", "HEAD"], include_in_schema=True)
@app.api_route(f"{settings.API_V1_STR}/health", methods=["GET", "HEAD"], include_in_schema=True)
async def health_ping():
    return {"status": "healthy"}


# Configure CORS origins cleanly
cors_origins: list[str] = ["*"]
if settings.BACKEND_CORS_ORIGINS:
    if isinstance(settings.BACKEND_CORS_ORIGINS, list):
        cors_origins = [str(o).rstrip("/") for o in settings.BACKEND_CORS_ORIGINS if o]
    elif isinstance(settings.BACKEND_CORS_ORIGINS, str):
        cors_origins = [
            str(o).strip().rstrip("/")
            for o in settings.BACKEND_CORS_ORIGINS.split(",")
            if o.strip()
        ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins or ["*"],
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
            "message": (
                str(exc)
                if settings.ENVIRONMENT == "development"
                else "An unexpected error occurred."
            ),
        },
    )


# Attach Version 1 API Router
app.include_router(api_router, prefix=settings.API_V1_STR)


# Convenience alias for /api/v1/docs -> /docs
@app.get(f"{settings.API_V1_STR}/docs", include_in_schema=False)
async def docs_alias():
    return RedirectResponse(url="/docs")


@app.get(f"{settings.API_V1_STR}/openapi.json", include_in_schema=False)
async def openapi_alias():
    return RedirectResponse(url="/openapi.json")
