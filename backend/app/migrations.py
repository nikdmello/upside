from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text

from .config import Settings
from .database import Base

APP_TABLE_NAMES = {
    "users",
    "auth_tokens",
    "home_states",
    "idempotency_keys",
    "feed_cards",
    "swipe_events",
}


def run_migrations(settings: Settings) -> None:
    config = alembic_config(settings)

    # Backfill Alembic version marker for legacy DBs created before migrations existed.
    maybe_stamp_legacy_database(settings, config)

    command.upgrade(config, "head")


def alembic_config(settings: Settings) -> Config:
    ini_path = Path("backend/alembic.ini")
    config = Config(str(ini_path))
    config.set_main_option("sqlalchemy.url", settings.database_url)
    return config


def maybe_stamp_legacy_database(settings: Settings, config: Config) -> None:
    connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
    engine = create_engine(settings.database_url, connect_args=connect_args)

    with engine.connect() as connection:
        inspector = inspect(connection)
        table_names = set(inspector.get_table_names())
        current_version = None
        if "alembic_version" in table_names:
            result = connection.execute(text("SELECT version_num FROM alembic_version LIMIT 1"))
            current_version = result.scalar()

    engine.dispose()

    has_alembic_version = "alembic_version" in table_names
    has_stamped_revision = bool(current_version)
    has_existing_app_tables = bool(APP_TABLE_NAMES.intersection(table_names))

    if has_existing_app_tables and (not has_alembic_version or not has_stamped_revision):
        # Legacy local DB existed before Alembic tracking. Backfill any missing tables
        # to current metadata shape, then mark as up-to-date so migrations can proceed.
        migration_engine = create_engine(settings.database_url, connect_args=connect_args)
        Base.metadata.create_all(bind=migration_engine)
        migration_engine.dispose()
        command.stamp(config, "head")
