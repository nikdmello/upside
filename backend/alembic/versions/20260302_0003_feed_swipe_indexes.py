"""add feed and swipe indexes

Revision ID: 20260302_0003
Revises: 20260227_0002
Create Date: 2026-03-02 10:00:00.000000
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "20260302_0003"
down_revision: Union[str, Sequence[str], None] = "20260227_0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        "ix_feed_cards_viewer_role_active_sort",
        "feed_cards",
        ["viewer_role", "is_active", "sort_order"],
        unique=False,
    )
    op.create_index(
        "ix_swipe_events_user_role_created",
        "swipe_events",
        ["user_id", "role", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_swipe_events_role_card_created",
        "swipe_events",
        ["role", "card_key", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_swipe_events_role_card_created", table_name="swipe_events")
    op.drop_index("ix_swipe_events_user_role_created", table_name="swipe_events")
    op.drop_index("ix_feed_cards_viewer_role_active_sort", table_name="feed_cards")
