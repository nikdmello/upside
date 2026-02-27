from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

RoleLiteral = Literal["creator", "brand"]


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
    current: Optional[HomeStatePayload] = None


class HealthResponse(BaseModel):
    ok: bool
    env: str
