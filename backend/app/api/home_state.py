import json
import time
from hashlib import sha256
from typing import Any, Optional

from fastapi import APIRouter, Body, Depends, Header, HTTPException, Query, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import HomeState, IdempotencyKey, User
from ..schemas import HomeStateConflictResponse, RoleLiteral

router = APIRouter(prefix="/v1/home-state", tags=["home-state"])


@router.get("/me")
def get_my_home_state(
    role: RoleLiteral = Query(..., description="Role scope for state"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(HomeState).where(HomeState.user_id == current_user.id, HomeState.role == role)
    state = db.execute(stmt).scalar_one_or_none()
    if state is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="State not found")

    payload = json.loads(state.payload_json)
    return sanitize_home_state_payload(payload)


@router.put("/me", status_code=status.HTTP_204_NO_CONTENT)
def put_my_home_state(
    payload: dict[str, Any] = Body(...),
    role: RoleLiteral = Query(..., description="Role scope for state"),
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    body = sanitize_home_state_payload(payload)

    last_updated_ms = body.get("lastUpdatedAt")
    if isinstance(last_updated_ms, float):
        last_updated_ms = int(last_updated_ms)
    if not isinstance(last_updated_ms, int) or last_updated_ms <= 0:
        last_updated_ms = int(time.time() * 1000)
        body["lastUpdatedAt"] = last_updated_ms

    schema_version = body.get("schemaVersion", 1)
    if isinstance(schema_version, float):
        schema_version = int(schema_version)
    if not isinstance(schema_version, int):
        schema_version = 1

    request_hash = sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()

    normalized_key = normalize_idempotency_key(idempotency_key)
    if normalized_key:
        existing = load_idempotency_record(
            db=db,
            user_id=current_user.id,
            method="PUT",
            path="/v1/home-state/me",
            key=normalized_key,
        )
        if existing is not None:
            if existing.request_hash != request_hash:
                return JSONResponse(
                    status_code=status.HTTP_409_CONFLICT,
                    content={"detail": "Idempotency key reused with different payload."},
                )
            return Response(status_code=existing.response_status_code)

    stmt = select(HomeState).where(HomeState.user_id == current_user.id, HomeState.role == role)
    state = db.execute(stmt).scalar_one_or_none()

    if state is None:
        state = HomeState(
            user_id=current_user.id,
            role=role,
            payload_json=json.dumps(body, separators=(",", ":")),
            schema_version=schema_version,
            last_updated_at_ms=last_updated_ms,
        )
        db.add(state)
    else:
        if last_updated_ms < state.last_updated_at_ms:
            current_payload = sanitize_home_state_payload(json.loads(state.payload_json))
            conflict = HomeStateConflictResponse(detail="Stale snapshot.", current=current_payload)
            return JSONResponse(
                status_code=status.HTTP_409_CONFLICT,
                content=conflict.model_dump(mode="json")
            )

        state.payload_json = json.dumps(body, separators=(",", ":"))
        state.schema_version = schema_version
        state.last_updated_at_ms = last_updated_ms

    if normalized_key:
        db.add(
            IdempotencyKey(
                user_id=current_user.id,
                method="PUT",
                path="/v1/home-state/me",
                key=normalized_key,
                request_hash=request_hash,
                response_status_code=status.HTTP_204_NO_CONTENT,
            )
        )

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def normalize_idempotency_key(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    normalized = value.strip()
    return normalized if normalized else None


def load_idempotency_record(
    db: Session,
    user_id: str,
    method: str,
    path: str,
    key: str,
) -> Optional[IdempotencyKey]:
    stmt = select(IdempotencyKey).where(
        IdempotencyKey.user_id == user_id,
        IdempotencyKey.method == method,
        IdempotencyKey.path == path,
        IdempotencyKey.key == key,
    )
    return db.execute(stmt).scalar_one_or_none()


def sanitize_home_state_payload(payload: dict[str, Any]) -> dict[str, Any]:
    body = dict(payload)

    if not isinstance(body.get("filters"), dict):
        body["filters"] = {}
    if not isinstance(body.get("profile"), dict):
        body["profile"] = {}
    if not isinstance(body.get("conversations"), list):
        body["conversations"] = []

    swiped = body.get("swipedCardKeys")
    saved = body.get("savedCardKeys")
    body["swipedCardKeys"] = [str(item) for item in swiped] if isinstance(swiped, list) else []
    body["savedCardKeys"] = [str(item) for item in saved] if isinstance(saved, list) else []

    if "schemaVersion" not in body:
        body["schemaVersion"] = 1
    if "lastUpdatedAt" not in body:
        body["lastUpdatedAt"] = 0

    return body
