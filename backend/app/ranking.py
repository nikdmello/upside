from __future__ import annotations

import re
from collections import defaultdict
from dataclasses import dataclass

from .models import FeedCard, SwipeEvent

TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
STOP_WORDS = {
    "and",
    "for",
    "the",
    "with",
    "from",
    "your",
    "this",
    "that",
    "into",
    "over",
    "under",
    "new",
    "high",
    "real",
    "team",
    "line",
}

USER_ACTION_WEIGHTS = {
    "match": 3.0,
    "save": 2.0,
    "skip": -2.5,
}

GLOBAL_ACTION_WEIGHTS = {
    "match": 1.4,
    "save": 0.9,
    "skip": -1.1,
}


@dataclass(frozen=True)
class RankedFeedCard:
    row: FeedCard
    payload: dict
    score: float
    reasons: list[str]
    match_score: int


def rank_feed_cards(
    cards: list[FeedCard],
    payload_by_key: dict[str, dict],
    user_events: list[SwipeEvent],
    global_events: list[SwipeEvent],
) -> list[RankedFeedCard]:
    if not cards:
        return []

    features_by_key = {
        card.key: extract_card_features(card_type=card.card_type, payload=payload_by_key.get(card.key, {}))
        for card in cards
    }
    user_token_scores = build_user_token_preferences(user_events=user_events, features_by_key=features_by_key)
    global_card_scores = build_global_card_scores(global_events=global_events)

    max_sort_order = max(card.sort_order for card in cards)
    ranked_cards: list[RankedFeedCard] = []

    for card in cards:
        features = features_by_key.get(card.key, set())
        personal_score = sum(user_token_scores.get(token, 0.0) for token in features)
        global_score = global_card_scores.get(card.key, 0.0)
        base_score = float(max_sort_order - card.sort_order) * 0.03
        total_score = (personal_score * 1.8) + (global_score * 1.2) + base_score

        reasons: list[str] = []
        if personal_score > 0.35:
            reasons.append("Aligned with your recent swipes")
        if global_score > 0.35:
            reasons.append("Popular with similar users")
        if not reasons:
            reasons.append("Fresh candidate")

        match_score = score_to_match_percent(total_score)
        ranked_cards.append(
            RankedFeedCard(
                row=card,
                payload=payload_by_key.get(card.key, {}),
                score=total_score,
                reasons=reasons,
                match_score=match_score,
            )
        )

    ranked_cards.sort(key=lambda item: (-item.score, item.row.sort_order, item.row.id))
    return ranked_cards


def build_seen_card_keys(events: list[SwipeEvent]) -> set[str]:
    return {event.card_key for event in events}


def build_user_token_preferences(
    user_events: list[SwipeEvent],
    features_by_key: dict[str, set[str]],
) -> dict[str, float]:
    token_scores: dict[str, float] = defaultdict(float)

    for index, event in enumerate(user_events):
        action_weight = USER_ACTION_WEIGHTS.get(event.action)
        if action_weight is None:
            continue

        tokens = features_by_key.get(event.card_key, set())
        if not tokens:
            continue

        recency_decay = 1 / (1 + (index * 0.08))
        weighted_value = action_weight * recency_decay
        for token in tokens:
            token_scores[token] += weighted_value

    return dict(token_scores)


def build_global_card_scores(global_events: list[SwipeEvent]) -> dict[str, float]:
    card_scores: dict[str, float] = defaultdict(float)

    for event in global_events:
        weight = GLOBAL_ACTION_WEIGHTS.get(event.action)
        if weight is None:
            continue
        card_scores[event.card_key] += weight

    # Cap extreme outliers so a single viral card does not dominate all requests.
    for key, value in list(card_scores.items()):
        card_scores[key] = value / (1 + (abs(value) / 8))

    return dict(card_scores)


def extract_card_features(card_type: str, payload: dict) -> set[str]:
    raw_parts: list[str] = []

    if card_type == "creator":
        raw_parts.extend(
            [
                str(payload.get("handle", "")),
                str(payload.get("niche", "")),
                str(payload.get("pitch", "")),
            ]
        )
    elif card_type == "brand":
        raw_parts.extend(
            [
                str(payload.get("name", "")),
                str(payload.get("campaign", "")),
                str(payload.get("deliverables", "")),
                str(payload.get("pitch", "")),
            ]
        )
    else:
        raw_parts.append(" ".join(str(v) for v in payload.values()))

    text = " ".join(raw_parts).lower()
    tokens = TOKEN_PATTERN.findall(text)
    return {
        token
        for token in tokens
        if len(token) >= 3 and not token.isnumeric() and token not in STOP_WORDS
    }


def score_to_match_percent(score: float) -> int:
    # Keep this stable and bounded for UI display.
    raw = 52 + (score * 8.5)
    return max(35, min(98, int(round(raw))))
