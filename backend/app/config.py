from functools import lru_cache

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"
    database_url: str = "sqlite:///./backend/data/upside_dev.sqlite3"
    auto_migrate: bool = True

    # For local/dev auth fallback.
    allow_dev_token_auth: bool = True
    seed_user_id: str = "dev-user-1"
    seed_user_email: str = "dev@upside.app"
    seed_bearer_token: str = "upside-dev-token"

    # JWT (production-grade path)
    jwt_issuer: Optional[str] = None
    jwt_audience: Optional[str] = None
    jwt_jwks_url: Optional[str] = None
    jwt_hs256_secret: Optional[str] = None
    jwt_algorithms: str = Field(default="RS256", description="Comma-separated alg list")

    # CORS
    cors_allow_origin: str = "*"

    @property
    def is_production_like(self) -> bool:
        return self.app_env.lower() in {"staging", "production", "prod"}

    @property
    def jwt_algorithm_list(self) -> list[str]:
        return [item.strip() for item in self.jwt_algorithms.split(",") if item.strip()]

    @model_validator(mode="after")
    def validate_non_dev_settings(self) -> "Settings":
        if self.is_production_like and self.database_url.startswith("sqlite"):
            raise ValueError("DATABASE_URL must be PostgreSQL in staging/production.")

        if self.is_production_like and self.allow_dev_token_auth:
            raise ValueError("ALLOW_DEV_TOKEN_AUTH must be false in staging/production.")

        if self.is_production_like and self.auto_migrate:
            raise ValueError("AUTO_MIGRATE must be false in staging/production.")

        has_jwks = bool(self.jwt_jwks_url)
        has_hs = bool(self.jwt_hs256_secret)
        if self.is_production_like and not (has_jwks or has_hs):
            raise ValueError("Configure JWT via JWT_JWKS_URL or JWT_HS256_SECRET in staging/production.")

        if has_jwks and has_hs:
            raise ValueError("Set either JWT_JWKS_URL or JWT_HS256_SECRET, not both.")

        return self


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
