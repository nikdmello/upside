import json

from fastapi import APIRouter, Depends, Query
from sqlalchemy import delete, desc, select
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..database import get_db
from ..models import FeedCard, SwipeEvent, User
from ..ranking import build_seen_card_keys, rank_feed_cards
from ..schemas import FeedCardsResponse, RoleLiteral, SwipeEventRequest, SwipeEventResponse, SwipeResetResponse

router = APIRouter(prefix="/v1", tags=["feed"])


@router.get("/feed", response_model=FeedCardsResponse)
def get_feed(
    role: RoleLiteral = Query(..., description="Viewer role scope"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    debug_ranking: bool = Query(False, alias="debugRanking"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cards_query = (
        select(FeedCard)
        .where(FeedCard.viewer_role == role, FeedCard.is_active.is_(True))
        .order_by(FeedCard.sort_order.asc(), FeedCard.id.asc())
    )
    rows = db.execute(cards_query).scalars().all()

    if not rows:
        return FeedCardsResponse(cards=[], nextOffset=None, hasMore=False)

    payload_by_key: dict[str, dict] = {}
    for row in rows:
        payload_by_key[row.key] = json.loads(row.payload_json)

    user_events_query = (
        select(SwipeEvent)
        .where(SwipeEvent.user_id == current_user.id, SwipeEvent.role == role)
        .order_by(desc(SwipeEvent.created_at))
        .limit(300)
    )
    user_events = db.execute(user_events_query).scalars().all()
    seen_keys = build_seen_card_keys(user_events)

    candidate_rows = [row for row in rows if row.key not in seen_keys]
    if not candidate_rows:
        return FeedCardsResponse(cards=[], nextOffset=None, hasMore=False)

    global_events_query = (
        select(SwipeEvent)
        .where(SwipeEvent.role == role)
        .order_by(desc(SwipeEvent.created_at))
        .limit(4000)
    )
    global_events = db.execute(global_events_query).scalars().all()

    ranked = rank_feed_cards(
        cards=candidate_rows,
        payload_by_key=payload_by_key,
        user_events=user_events,
        global_events=global_events,
    )

    total = len(ranked)
    page = ranked[offset: offset + limit]
    has_more = (offset + len(page)) < total

    cards: list[dict] = []
    for ranked_card in page:
        payload = dict(ranked_card.payload)
        payload["cardKey"] = ranked_card.row.key
        payload["cardType"] = ranked_card.row.card_type
        payload["matchScore"] = ranked_card.match_score
        payload["matchReason"] = ranked_card.reasons[0]
        if debug_ranking:
            payload["rankingDebug"] = {
                "score": round(ranked_card.score, 4),
                "reasons": ranked_card.reasons,
            }
        cards.append(payload)

    next_offset = offset + len(cards) if has_more else None
    return FeedCardsResponse(cards=cards, nextOffset=next_offset, hasMore=has_more)


@router.post("/swipes", response_model=SwipeEventResponse)
def post_swipe_event(
    request: SwipeEventRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.add(
        SwipeEvent(
            user_id=current_user.id,
            role=request.role,
            card_key=request.cardKey,
            action=request.action,
        )
    )
    db.commit()
    return SwipeEventResponse(ok=True)


@router.delete("/swipes/me", response_model=SwipeResetResponse)
def delete_my_swipes(
    role: RoleLiteral = Query(..., description="Viewer role scope"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = db.execute(
        delete(SwipeEvent).where(
            SwipeEvent.user_id == current_user.id,
            SwipeEvent.role == role,
        )
    )
    db.commit()
    return SwipeResetResponse(ok=True, deleted=result.rowcount or 0)
