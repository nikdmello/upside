from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

RoleLiteral = Literal["creator", "brand"]
SwipeActionLiteral = Literal["skip", "save", "match"]


class HomeStatePayload(BaseModel):
    model_config = ConfigDict(extra="allow")

    schemaVersion: int = 1
    lastUpdatedAt: int = Field(default=0)
    filters: dict[str, Any] = Field(default_factory=dict)
    profile: dict[str, Any] = Field(default_factory=dict)
    conversations: list[dict[str, Any]] = Field(default_factory=list)
    swipedCardKeys: list[str] = Field(default_factory=list)
    savedCardKeys: list[str] = Field(default_factory=list)


class HomeStateConflictResponse(BaseModel):
    detail: str
    current: Optional[dict[str, Any]] = None


class FeedCardsResponse(BaseModel):
    cards: list[dict[str, Any]]
    nextOffset: Optional[int]
    hasMore: bool


class SwipeEventRequest(BaseModel):
    role: RoleLiteral
    cardKey: str
    action: SwipeActionLiteral


class SwipeEventResponse(BaseModel):
    ok: bool = True


class SwipeResetResponse(BaseModel):
    ok: bool = True
    deleted: int = 0


class AuthMeResponse(BaseModel):
    userId: str
    email: Optional[str] = None


class HealthResponse(BaseModel):
    ok: bool
    env: str
