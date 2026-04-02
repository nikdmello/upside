import json

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .models import FeedCard


def seed_feed_cards(db: Session) -> None:
    existing_count = db.scalar(select(func.count()).select_from(FeedCard)) or 0
    if existing_count > 0:
        return

    for index, card in enumerate(seed_cards()):
        db.add(
            FeedCard(
                key=card["key"],
                viewer_role=card["viewerRole"],
                card_type=card["cardType"],
                payload_json=json.dumps(card["payload"], separators=(",", ":")),
                sort_order=index,
                is_active=True,
            )
        )
    db.commit()


def seed_cards() -> list[dict]:
    return creator_viewer_cards() + brand_viewer_cards()


def creator_viewer_cards() -> list[dict]:
    return [
        {
            "key": "brand-nike",
            "viewerRole": "creator",
            "cardType": "brand",
            "payload": {
                "name": "Nike",
                "imageName": "Brand_Nike",
                "campaign": "UGC Reels for new training line",
                "budget": "AED 500-AED 2,000",
                "deliverables": "2 Reels, 1 Story",
                "pitch": "Looking for fitness creators with high engagement.",
            },
        },
        {
            "key": "brand-sephora",
            "viewerRole": "creator",
            "cardType": "brand",
            "payload": {
                "name": "Sephora",
                "imageName": "Brand_Sephora",
                "campaign": "GRWM short-form series",
                "budget": "AED 300-AED 1,200",
                "deliverables": "3 Shorts, 1 Post",
                "pitch": "Beauty creators who love new drops and reviews.",
            },
        },
        {
            "key": "brand-allbirds",
            "viewerRole": "creator",
            "cardType": "brand",
            "payload": {
                "name": "Allbirds",
                "imageName": "Brand_Allbirds",
                "campaign": "Lifestyle sneaker launch",
                "budget": "AED 400-AED 1,500",
                "deliverables": "2 Reels, 2 Stories",
                "pitch": "Eco-friendly lifestyle creators with clean aesthetic.",
            },
        },
        {
            "key": "brand-apple",
            "viewerRole": "creator",
            "cardType": "brand",
            "payload": {
                "name": "Apple",
                "imageName": "Brand_Apple",
                "campaign": "Shot on iPhone stories",
                "budget": "AED 700-AED 2,500",
                "deliverables": "1 Reel, 2 Stories",
                "pitch": "Creators who can spotlight real-world camera use.",
            },
        },
        {
            "key": "brand-spotify",
            "viewerRole": "creator",
            "cardType": "brand",
            "payload": {
                "name": "Spotify",
                "imageName": "Brand_Spotify",
                "campaign": "Playlist launch collab",
                "budget": "AED 300-AED 900",
                "deliverables": "1 Reel, 1 Story",
                "pitch": "Music creators with strong community engagement.",
            },
        },
    ]


def brand_viewer_cards() -> list[dict]:
    return [
        {
            "key": "creator-@nikdmello",
            "viewerRole": "brand",
            "cardType": "creator",
            "payload": {
                "handle": "@nikdmello",
                "imageName": "Creator_nikdmello",
                "niche": "Tech • Product",
                "followers": "210K",
                "engagementRate": "5.1% ER",
                "pitch": "Product storytelling that drives intent.",
            },
        },
        {
            "key": "creator-@abdulmurad_",
            "viewerRole": "brand",
            "cardType": "creator",
            "payload": {
                "handle": "@abdulmurad_",
                "imageName": "Creator_abdulmurad_",
                "niche": "Fashion • Streetwear",
                "followers": "142K",
                "engagementRate": "4.8% ER",
                "pitch": "Clean aesthetic and strong conversion on drops.",
            },
        },
        {
            "key": "creator-@jxshdxniells",
            "viewerRole": "brand",
            "cardType": "creator",
            "payload": {
                "handle": "@jxshdxniells",
                "imageName": "Creator_jxshdxniells",
                "niche": "Culture • Lifestyle",
                "followers": "76K",
                "engagementRate": "3.6% ER",
                "pitch": "High-retention short-form with community pull.",
            },
        },
        {
            "key": "creator-@srav.ya",
            "viewerRole": "brand",
            "cardType": "creator",
            "payload": {
                "handle": "@srav.ya",
                "imageName": "Creator_srav.ya",
                "niche": "Travel • Lifestyle",
                "followers": "86K",
                "engagementRate": "3.9% ER",
                "pitch": "Authentic storytelling with premium brands.",
            },
        },
        {
            "key": "creator-@mikethurston",
            "viewerRole": "brand",
            "cardType": "creator",
            "payload": {
                "handle": "@mikethurston",
                "imageName": "Creator_mikethurston",
                "niche": "Fitness • Lifestyle",
                "followers": "128K",
                "engagementRate": "4.3% ER",
                "pitch": "Creates high-converting short-form with real energy.",
            },
        },
    ]
