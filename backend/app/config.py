from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"
    database_url: str = "sqlite:///./backend/data/upside_dev.sqlite3"

    # For local/dev auth. In production replace with JWT verification.
    seed_user_id: str = "dev-user-1"
    seed_user_email: str = "dev@upside.app"
    seed_bearer_token: str = "upside-dev-token"

    # CORS
    cors_allow_origin: str = "*"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
