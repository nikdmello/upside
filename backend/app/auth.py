import hashlib
from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from .config import Settings, get_settings
from .database import get_db
from .models import AuthToken, User


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def seed_dev_identity(db: Session, settings: Settings) -> None:
    user = db.get(User, settings.seed_user_id)
    if user is None:
        user = User(id=settings.seed_user_id, email=settings.seed_user_email)
        db.add(user)
        db.flush()

    token_hash = hash_token(settings.seed_bearer_token)
    existing = db.get(AuthToken, token_hash)
    if existing is None:
        db.add(AuthToken(token_hash=token_hash, user_id=user.id))

    db.commit()


def get_current_user(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

    token_hash = hash_token(token)
    auth_token = db.get(AuthToken, token_hash)
    if auth_token is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = db.get(User, auth_token.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return user
