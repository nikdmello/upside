from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.auth import router as auth_router
from .api.feed import router as feed_router
from .api.home_state import router as home_state_router
from .auth import seed_dev_identity
from .config import get_settings
from .database import SessionLocal
from .middleware import RequestIDMiddleware
from .migrations import run_migrations
from .schemas import HealthResponse
from .seed import seed_feed_cards

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.auto_migrate:
        run_migrations(settings)
    with SessionLocal() as db:
        seed_dev_identity(db, settings)
        seed_feed_cards(db)
    yield


app = FastAPI(title="Upside API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.cors_allow_origin],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestIDMiddleware)

@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(ok=True, env=settings.app_env)


app.include_router(home_state_router)
app.include_router(feed_router)
app.include_router(auth_router)
