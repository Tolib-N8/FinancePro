"""seed system categories

Revision ID: 0002
Revises: 0001
Create Date: 2026-04-08

"""
import uuid
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

SYSTEM_CATEGORIES = [
    ("Food & Dining", "#FF6B6B", "restaurant"),
    ("Transport", "#4ECDC4", "directions_car"),
    ("Housing", "#45B7D1", "home"),
    ("Health", "#96CEB4", "local_hospital"),
    ("Entertainment", "#FFEAA7", "movie"),
    ("Shopping", "#DDA0DD", "shopping_cart"),
    ("Utilities", "#98D8C8", "bolt"),
    ("Education", "#F7DC6F", "school"),
    ("Travel", "#85C1E9", "flight"),
    ("Income", "#2ECC71", "trending_up"),
    ("Transfer", "#BDC3C7", "swap_horiz"),
    ("Other", "#95A5A6", "more_horiz"),
]


def upgrade() -> None:
    categories_table = sa.table(
        "categories",
        sa.column("id", postgresql.UUID()),
        sa.column("name", sa.String()),
        sa.column("color", sa.String()),
        sa.column("icon", sa.String()),
        sa.column("is_system", sa.Boolean()),
    )
    op.bulk_insert(
        categories_table,
        [
            {"id": str(uuid.uuid4()), "name": name, "color": color, "icon": icon, "is_system": True}
            for name, color, icon in SYSTEM_CATEGORIES
        ],
    )


def downgrade() -> None:
    op.execute("DELETE FROM categories WHERE is_system = true")
