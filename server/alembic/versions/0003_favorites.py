"""Add favorites table for course/paper bookmarks."""

from alembic import op
import sqlalchemy as sa


revision = "0003_favorites"
down_revision = "0002_ai_full_stack"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "favorites",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("student_profile_id", sa.Integer(), sa.ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("title", sa.String(150), nullable=False),
        sa.Column("subtitle", sa.String(150), nullable=False, server_default=""),
        sa.Column("tag", sa.String(50), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("student_profile_id", "target_id", "type", name="uq_student_favorite"),
    )
    op.create_index("ix_favorites_student_profile_id", "favorites", ["student_profile_id"])
    op.create_index("ix_favorites_target_id", "favorites", ["target_id"])
    op.create_index("ix_favorites_type", "favorites", ["type"])


def downgrade() -> None:
    op.drop_index("ix_favorites_type", table_name="favorites")
    op.drop_index("ix_favorites_target_id", table_name="favorites")
    op.drop_index("ix_favorites_student_profile_id", table_name="favorites")
    op.drop_table("favorites")
