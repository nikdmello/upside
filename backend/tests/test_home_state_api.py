import os
from pathlib import Path

from fastapi.testclient import TestClient

# Keep tests isolated from developer local data.
TEST_DB_PATH = Path("backend/data/upside_test.sqlite3")
if TEST_DB_PATH.exists():
    TEST_DB_PATH.unlink()

os.environ["DATABASE_URL"] = "sqlite:///./backend/data/upside_test.sqlite3"
os.environ["SEED_USER_ID"] = "test-user-1"
os.environ["SEED_USER_EMAIL"] = "test@upside.app"
os.environ["SEED_BEARER_TOKEN"] = "upside-test-token"

from backend.app.auth import seed_dev_identity  # noqa: E402
from backend.app.config import get_settings  # noqa: E402
from backend.app.database import Base, SessionLocal, engine  # noqa: E402
from backend.app.main import app  # noqa: E402

client = TestClient(app)
AUTH_HEADERS = {"Authorization": "Bearer upside-test-token"}


def reset_database() -> None:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_dev_identity(db, get_settings())


def make_payload(last_updated_at: int) -> dict:
    return {
        "schemaVersion": 1,
        "lastUpdatedAt": last_updated_at,
        "filters": {"minimumCreatorFollowers": 50_000},
        "profile": {
            "displayName": "Upside Demo",
            "headline": "Brand • Growth",
            "bio": "Demo profile for tests.",
            "location": "Dubai, UAE",
            "email": "demo@upside.app",
            "websiteOrHandle": "upside.app",
        },
        "conversations": [],
        "swipedCardKeys": ["creator-@example"],
        "savedCardKeys": ["creator-@saved"],
    }


def test_health() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["ok"] is True
    assert payload["env"] == "development"


def test_home_state_requires_auth() -> None:
    reset_database()
    response = client.get("/v1/home-state/me", params={"role": "brand"})

    assert response.status_code == 401


def test_put_and_get_my_home_state_roundtrip() -> None:
    reset_database()
    payload = make_payload(last_updated_at=1_700_000_001_000)

    put_response = client.put("/v1/home-state/me", params={"role": "brand"}, json=payload, headers=AUTH_HEADERS)
    assert put_response.status_code == 204

    get_response = client.get("/v1/home-state/me", params={"role": "brand"}, headers=AUTH_HEADERS)
    assert get_response.status_code == 200
    body = get_response.json()
    assert body["lastUpdatedAt"] == payload["lastUpdatedAt"]
    assert body["profile"]["displayName"] == "Upside Demo"
    assert body["swipedCardKeys"] == ["creator-@example"]


def test_put_rejects_stale_snapshot_with_conflict() -> None:
    reset_database()

    newest_payload = make_payload(last_updated_at=1_700_000_005_000)
    stale_payload = make_payload(last_updated_at=1_700_000_001_000)

    first_write = client.put("/v1/home-state/me", params={"role": "creator"}, json=newest_payload, headers=AUTH_HEADERS)
    assert first_write.status_code == 204

    stale_write = client.put("/v1/home-state/me", params={"role": "creator"}, json=stale_payload, headers=AUTH_HEADERS)
    assert stale_write.status_code == 409
    conflict_body = stale_write.json()
    assert conflict_body["detail"] == "Stale snapshot."
    assert conflict_body["current"]["lastUpdatedAt"] == newest_payload["lastUpdatedAt"]

    get_response = client.get("/v1/home-state/me", params={"role": "creator"}, headers=AUTH_HEADERS)
    assert get_response.status_code == 200
    assert get_response.json()["lastUpdatedAt"] == newest_payload["lastUpdatedAt"]
