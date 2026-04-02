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
os.environ["JWT_HS256_SECRET"] = "upside-test-jwt-secret"
os.environ["JWT_ALGORITHMS"] = "HS256"

from backend.app.auth import seed_dev_identity  # noqa: E402
from backend.app.config import get_settings  # noqa: E402
from backend.app.database import Base, SessionLocal, engine  # noqa: E402
from backend.app.main import app  # noqa: E402
from backend.app.seed import seed_feed_cards  # noqa: E402
from backend.app.models import SwipeEvent, User  # noqa: E402
import jwt  # noqa: E402

client = TestClient(app)
AUTH_HEADERS = {"Authorization": "Bearer upside-test-token"}


def reset_database() -> None:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_dev_identity(db, get_settings())
        seed_feed_cards(db)


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
    assert response.headers.get("x-request-id")


def test_home_state_requires_auth() -> None:
    reset_database()
    response = client.get("/v1/home-state/me", params={"role": "brand"})

    assert response.status_code == 401


def test_auth_me_returns_current_user_for_dev_token() -> None:
    reset_database()

    response = client.get("/v1/auth/me", headers=AUTH_HEADERS)

    assert response.status_code == 200
    assert response.json() == {
        "userId": "test-user-1",
        "email": "test@upside.app",
    }


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


def test_idempotency_replay_returns_same_success() -> None:
    reset_database()
    payload = make_payload(last_updated_at=1_700_000_020_000)
    headers = {
        **AUTH_HEADERS,
        "Idempotency-Key": "brand-state-001",
    }

    first_write = client.put("/v1/home-state/me", params={"role": "brand"}, json=payload, headers=headers)
    assert first_write.status_code == 204

    second_write = client.put("/v1/home-state/me", params={"role": "brand"}, json=payload, headers=headers)
    assert second_write.status_code == 204


def test_idempotency_reuse_with_different_payload_conflicts() -> None:
    reset_database()
    first_payload = make_payload(last_updated_at=1_700_000_030_000)
    second_payload = make_payload(last_updated_at=1_700_000_031_000)
    second_payload["profile"]["displayName"] = "Changed Name"

    headers = {
        **AUTH_HEADERS,
        "Idempotency-Key": "brand-state-002",
    }

    first_write = client.put("/v1/home-state/me", params={"role": "brand"}, json=first_payload, headers=headers)
    assert first_write.status_code == 204

    second_write = client.put("/v1/home-state/me", params={"role": "brand"}, json=second_payload, headers=headers)
    assert second_write.status_code == 409
    assert second_write.json()["detail"] == "Idempotency key reused with different payload."


def test_jwt_auth_path_supports_user_upsert() -> None:
    reset_database()

    token = jwt.encode(
        {"sub": "jwt-user-1", "email": "jwt-user@upside.app"},
        key="upside-test-jwt-secret",
        algorithm="HS256",
    )
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get("/v1/home-state/me", params={"role": "brand"}, headers=headers)
    assert response.status_code == 404


def test_auth_me_supports_jwt_user_upsert() -> None:
    reset_database()

    token = jwt.encode(
        {"sub": "jwt-user-2", "email": "jwt-user-2@upside.app"},
        key="upside-test-jwt-secret",
        algorithm="HS256",
    )
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get("/v1/auth/me", headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "userId": "jwt-user-2",
        "email": "jwt-user-2@upside.app",
    }


def test_feed_endpoint_returns_cards() -> None:
    reset_database()
    response = client.get("/v1/feed", params={"role": "brand", "limit": 5, "offset": 0}, headers=AUTH_HEADERS)

    assert response.status_code == 200
    body = response.json()
    assert "cards" in body
    assert len(body["cards"]) > 0
    first = body["cards"][0]
    assert first["cardType"] == "creator"
    assert first["cardKey"].startswith("creator-")


def test_swipe_endpoint_persists_event() -> None:
    reset_database()
    request = {
        "role": "brand",
        "cardKey": "creator-@nikdmello",
        "action": "match",
    }

    response = client.post("/v1/swipes", json=request, headers=AUTH_HEADERS)
    assert response.status_code == 200
    assert response.json()["ok"] is True

    with SessionLocal() as db:
        events = db.query(SwipeEvent).all()
        assert len(events) == 1
        assert events[0].card_key == "creator-@nikdmello"


def test_feed_hides_previously_swiped_cards_for_user() -> None:
    reset_database()

    first_response = client.get("/v1/feed", params={"role": "brand", "limit": 5, "offset": 0}, headers=AUTH_HEADERS)
    assert first_response.status_code == 200
    first_key = first_response.json()["cards"][0]["cardKey"]

    swipe_response = client.post(
        "/v1/swipes",
        json={"role": "brand", "cardKey": first_key, "action": "skip"},
        headers=AUTH_HEADERS,
    )
    assert swipe_response.status_code == 200

    second_response = client.get("/v1/feed", params={"role": "brand", "limit": 5, "offset": 0}, headers=AUTH_HEADERS)
    assert second_response.status_code == 200
    keys_after = [card["cardKey"] for card in second_response.json()["cards"]]
    assert first_key not in keys_after


def test_delete_my_swipes_restores_feed_candidates() -> None:
    reset_database()

    first_response = client.get("/v1/feed", params={"role": "brand", "limit": 5, "offset": 0}, headers=AUTH_HEADERS)
    assert first_response.status_code == 200
    first_key = first_response.json()["cards"][0]["cardKey"]

    swipe_response = client.post(
        "/v1/swipes",
        json={"role": "brand", "cardKey": first_key, "action": "skip"},
        headers=AUTH_HEADERS,
    )
    assert swipe_response.status_code == 200

    reset_response = client.delete("/v1/swipes/me", params={"role": "brand"}, headers=AUTH_HEADERS)
    assert reset_response.status_code == 200
    assert reset_response.json()["ok"] is True

    after_reset = client.get("/v1/feed", params={"role": "brand", "limit": 5, "offset": 0}, headers=AUTH_HEADERS)
    assert after_reset.status_code == 200
    keys = [card["cardKey"] for card in after_reset.json()["cards"]]
    assert first_key in keys


def test_feed_uses_global_swipe_signals_to_rerank() -> None:
    reset_database()

    with SessionLocal() as db:
        db.add_all(
            [
                User(id="signal-user-1", email="signal1@upside.app"),
                User(id="signal-user-2", email="signal2@upside.app"),
                User(id="signal-user-3", email="signal3@upside.app"),
            ]
        )
        db.flush()
        db.add_all(
            [
                SwipeEvent(user_id="signal-user-1", role="brand", card_key="creator-@mikethurston", action="match"),
                SwipeEvent(user_id="signal-user-2", role="brand", card_key="creator-@mikethurston", action="match"),
                SwipeEvent(user_id="signal-user-3", role="brand", card_key="creator-@abdulmurad_", action="skip"),
            ]
        )
        db.commit()

    response = client.get("/v1/feed", params={"role": "brand", "limit": 5, "offset": 0}, headers=AUTH_HEADERS)
    assert response.status_code == 200
    keys = [card["cardKey"] for card in response.json()["cards"]]

    assert keys[0] == "creator-@mikethurston"
