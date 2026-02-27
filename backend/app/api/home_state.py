import json
import time

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import HomeState, User
from ..schemas import HomeStateConflictResponse, HomeStatePayload, RoleLiteral

router = APIRouter(prefix="/v1/home-state", tags=["home-state"])


@router.get("/me", response_model=HomeStatePayload)
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
    return HomeStatePayload.model_validate(payload)


@router.put("/me", status_code=status.HTTP_204_NO_CONTENT)
def put_my_home_state(
    payload: HomeStatePayload,
    role: RoleLiteral = Query(..., description="Role scope for state"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    body = payload.model_dump(mode="json")

    last_updated_ms = body.get("lastUpdatedAt")
    if not isinstance(last_updated_ms, int) or last_updated_ms <= 0:
        last_updated_ms = int(time.time() * 1000)
        body["lastUpdatedAt"] = last_updated_ms

    schema_version = body.get("schemaVersion", 1)
    if not isinstance(schema_version, int):
        schema_version = 1

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
            current_payload = HomeStatePayload.model_validate(json.loads(state.payload_json))
            conflict = HomeStateConflictResponse(detail="Stale snapshot.", current=current_payload)
            return JSONResponse(
                status_code=status.HTTP_409_CONFLICT,
                content=conflict.model_dump(mode="json")
            )

        state.payload_json = json.dumps(body, separators=(",", ":"))
        state.schema_version = schema_version
        state.last_updated_at_ms = last_updated_ms

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
