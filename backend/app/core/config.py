import json

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Core Application Settings (Render Configuration)
    PROJECT_NAME: str = "Nearo API"
    API_V1_STR: str = "/api/v1"
    SUBDOMAIN: str = "nearo.asiverticals.me"
    ENVIRONMENT: str = "development"

    # Security & Cryptographic Tokens
    SECRET_KEY: str = "nearo-insecure-secret-key-change-in-production-dpdp-compliance"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60  # 60 minutes lifetime
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30  # 30 days sliding refresh

    # Clerk Authentication (Phone SMS OTP / JWKS Token Verification)
    CLERK_PUBLISHABLE_KEY: str | None = None
    CLERK_SECRET_KEY: str | None = None
    CLERK_ISSUER_URL: str | None = None
    CLERK_JWKS_URL: str | None = "https://api.clerk.com/v1/jwks"

    # Supabase PostgreSQL 16 + PostGIS Spatial Database (Mumbai AWS pooler)
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "nearo_user"
    POSTGRES_PASSWORD: str = "nearo_password"
    POSTGRES_DB: str = "nearo_db"
    DATABASE_URL: str | None = None

    @property
    def async_database_url(self) -> str:
        if self.DATABASE_URL:
            url = self.DATABASE_URL
            # Ensure asyncpg dialect prefix for Supabase / PostgreSQL URLs
            if url.startswith("postgres://"):
                url = url.replace("postgres://", "postgresql+asyncpg://", 1)
            elif url.startswith("postgresql://") and not url.startswith(
                "postgresql+asyncpg://"
            ):
                url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
            return url
        return (
            f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@"
            f"{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    # Redis / Upstash Cache & Real-time PubSub Broker
    REDIS_URL: str | None = "redis://localhost:6379/0"

    # CORS Allowed Origins
    BACKEND_CORS_ORIGINS: list[str] | str = [
        "http://localhost:3000",
        "http://localhost:8000",
        "https://nearo.asiverticals.me",
        "https://*.asiverticals.me",
    ]

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            v_clean = v.strip()
            if v_clean.startswith("[") and v_clean.endswith("]"):
                try:
                    parsed = json.loads(v_clean)
                    if isinstance(parsed, list):
                        return [str(i).strip() for i in parsed if str(i).strip()]
                except Exception:
                    pass
            return [i.strip() for i in v_clean.split(",") if i.strip()]
        elif isinstance(v, list):
            return [str(i).strip() for i in v if str(i).strip()]
        return v

    # Google Play In-App Billing & Subscriptions
    GOOGLE_PLAY_PACKAGE_NAME: str = "me.asiverticals.nearo"
    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: str | None = None  # Base64 string or filepath

    # Google AdMob Hyperlocal Ad Units
    ADMOB_APP_ID: str = "ca-app-pub-3940256099942544~3347511713"
    ADMOB_BANNER_AD_UNIT_ID: str = "ca-app-pub-3940256099942544/6300978111"
    ADMOB_NATIVE_AD_UNIT_ID: str = "ca-app-pub-3940256099942544/2247696110"

    # Hyperlocal Geospatial & Privacy Jitter Constraints
    DEFAULT_RADIUS_METERS: int = 1500
    MAX_RADIUS_METERS: int = 5000
    COORDINATE_JITTER_MIN_METERS: int = 100
    COORDINATE_JITTER_MAX_METERS: int = 250

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


settings = Settings()
