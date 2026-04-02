import hashlib
from dataclasses import dataclass
from typing import Optional

import jwt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from .config import Settings, get_settings
from .database import get_db
from .models import AuthToken, User


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def seed_dev_identity(db: Session, settings: Settings) -> None:
    if not settings.allow_dev_token_auth:
        return

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


@dataclass
class TokenSubject:
    user_id: str
    email: Optional[str]


def get_current_user(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> User:
    token = parse_bearer_token(authorization)

    try:
        subject = verify_jwt_token(token=token, settings=settings)
        if subject is not None:
            return upsert_user_from_subject(db=db, subject=subject)
    except HTTPException:
        if not settings.allow_dev_token_auth:
            raise

    if settings.allow_dev_token_auth:
        return verify_dev_token(db=db, token=token)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid token",
    )


def parse_bearer_token(authorization: Optional[str]) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    return token


def verify_jwt_token(token: str, settings: Settings) -> Optional[TokenSubject]:
    # JWT mode is active if either JWKS or HS256 secret is configured.
    if not settings.jwt_jwks_url and not settings.jwt_hs256_secret:
        return None

    decode_options = {
        "verify_signature": True,
        "verify_exp": True,
    }
    if settings.jwt_audience:
        decode_options["verify_aud"] = True
    else:
        decode_options["verify_aud"] = False

    kwargs = {
        "algorithms": settings.jwt_algorithm_list,
        "options": decode_options,
    }
    if settings.jwt_audience:
        kwargs["audience"] = settings.jwt_audience
    if settings.jwt_issuer:
        kwargs["issuer"] = settings.jwt_issuer

    try:
        if settings.jwt_jwks_url:
            jwks_client = jwt.PyJWKClient(settings.jwt_jwks_url)
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            claims = jwt.decode(token, signing_key.key, **kwargs)
        else:
            # HS256 shared-secret mode (useful for local integration tests).
            claims = jwt.decode(token, settings.jwt_hs256_secret, **kwargs)
    except jwt.PyJWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid JWT")

    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject.strip():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="JWT missing subject")

    email = claims.get("email")
    if email is not None and not isinstance(email, str):
        email = None

    return TokenSubject(user_id=subject.strip(), email=email)


def upsert_user_from_subject(db: Session, subject: TokenSubject) -> User:
    user = db.get(User, subject.user_id)
    if user is None:
        user = User(id=subject.user_id, email=subject.email)
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    if subject.email and subject.email != user.email:
        user.email = subject.email
        db.commit()
        db.refresh(user)

    return user


def verify_dev_token(db: Session, token: str) -> User:
    token_hash = hash_token(token)
    auth_token = db.get(AuthToken, token_hash)
    if auth_token is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = db.get(User, auth_token.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return user
