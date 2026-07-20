"""Add AI business records, RAG storage, and idempotent requests."""

from alembic import op
import sqlalchemy as sa


revision = "0002_ai_full_stack"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def timestamp_columns() -> list[sa.Column]:
    return [
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    ]


def upgrade() -> None:
    # 开发环境若有热重载进程，SQLAlchemy create_all 可能已先创建本版本全部结构。
    # 只有在所需表和增量列都完整存在时才直接视为已应用，绝不删除或重建业务数据。
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    required_tables = {
        "course_orders", "course_enrollments", "paper_questions", "practice_attempts",
        "practice_answers", "wrong_questions", "rag_documents", "rag_chunks", "ai_requests",
    }
    required_columns = {
        "courses": {"price", "total_lessons"},
        "study_tasks": {"scheduled_date", "duration_minutes", "knowledge_point", "source_session_id"},
        "chat_messages": {"client_message_id", "tool_calls_json", "model_metadata_json"},
        "tool_call_logs": {"request_id", "status", "error_code"},
    }
    columns_ready = all(
        expected.issubset({column["name"] for column in inspector.get_columns(table)})
        for table, expected in required_columns.items()
    )
    if required_tables.issubset(tables) and columns_ready:
        return

    op.add_column("courses", sa.Column("price", sa.Numeric(10, 2), nullable=False, server_default="99.00"))
    op.add_column("courses", sa.Column("total_lessons", sa.Integer(), nullable=False, server_default="12"))
    op.add_column("study_tasks", sa.Column("scheduled_date", sa.Date(), nullable=True))
    op.add_column("study_tasks", sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default="40"))
    op.add_column("study_tasks", sa.Column("knowledge_point", sa.String(100), nullable=False, server_default=""))
    op.add_column("study_tasks", sa.Column("source_session_id", sa.String(36), nullable=True))
    op.add_column("chat_messages", sa.Column("client_message_id", sa.String(64), nullable=True))
    op.add_column("chat_messages", sa.Column("tool_calls_json", sa.JSON(), nullable=True))
    op.add_column("chat_messages", sa.Column("model_metadata_json", sa.JSON(), nullable=True))
    op.create_index("ix_chat_messages_client_message_id", "chat_messages", ["client_message_id"])
    op.add_column("tool_call_logs", sa.Column("request_id", sa.String(64), nullable=False, server_default=""))
    op.add_column("tool_call_logs", sa.Column("status", sa.String(20), nullable=False, server_default="completed"))
    op.add_column("tool_call_logs", sa.Column("error_code", sa.String(50), nullable=False, server_default=""))
    op.create_index("ix_tool_call_logs_request_id", "tool_call_logs", ["request_id"])

    op.create_table(
        "course_orders",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("order_no", sa.String(40), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("student_profile_id", sa.Integer(), sa.ForeignKey("student_profiles.id"), nullable=False),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="PENDING"),
        sa.Column("paid_at", sa.DateTime(), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(), nullable=True),
        *timestamp_columns(),
        sa.UniqueConstraint("order_no", name="uq_course_order_no"),
    )
    op.create_index("ix_course_orders_user_id", "course_orders", ["user_id"])
    op.create_index("ix_course_orders_student_profile_id", "course_orders", ["student_profile_id"])
    op.create_index("ix_course_orders_course_id", "course_orders", ["course_id"])
    op.create_index("ix_course_orders_status", "course_orders", ["status"])

    op.create_table(
        "course_enrollments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("student_profile_id", sa.Integer(), sa.ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("order_id", sa.Integer(), sa.ForeignKey("course_orders.id"), nullable=False, unique=True),
        sa.Column("completed_lessons", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_lessons", sa.Integer(), nullable=False, server_default="12"),
        sa.Column("progress", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(20), nullable=False, server_default="LEARNING"),
        sa.Column("next_lesson", sa.String(150), nullable=False, server_default="第一课"),
        *timestamp_columns(),
        sa.UniqueConstraint("student_profile_id", "course_id", name="uq_student_course"),
    )
    op.create_index("ix_course_enrollments_student_profile_id", "course_enrollments", ["student_profile_id"])
    op.create_index("ix_course_enrollments_course_id", "course_enrollments", ["course_id"])

    op.create_table(
        "paper_questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("paper_id", sa.Integer(), sa.ForeignKey("papers.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("stem", sa.Text(), nullable=False),
        sa.Column("options_json", sa.JSON(), nullable=False),
        sa.Column("correct_index", sa.Integer(), nullable=False),
        sa.Column("explanation", sa.Text(), nullable=False),
        sa.Column("knowledge_point", sa.String(100), nullable=False),
        *timestamp_columns(),
        sa.UniqueConstraint("paper_id", "sequence", name="uq_paper_question_sequence"),
    )
    op.create_index("ix_paper_questions_paper_id", "paper_questions", ["paper_id"])

    op.create_table(
        "practice_attempts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("student_profile_id", sa.Integer(), sa.ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("paper_id", sa.Integer(), sa.ForeignKey("papers.id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("score", sa.Float(), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("question_count", sa.Integer(), nullable=False),
        sa.Column("knowledge_stats_json", sa.JSON(), nullable=False),
        sa.Column("submitted_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        *timestamp_columns(),
    )
    op.create_index("ix_practice_attempts_student_profile_id", "practice_attempts", ["student_profile_id"])
    op.create_index("ix_practice_attempts_paper_id", "practice_attempts", ["paper_id"])

    op.create_table(
        "practice_answers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("attempt_id", sa.Integer(), sa.ForeignKey("practice_attempts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("question_id", sa.Integer(), sa.ForeignKey("paper_questions.id"), nullable=False),
        sa.Column("selected_index", sa.Integer(), nullable=False),
        sa.Column("correct", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("attempt_id", "question_id", name="uq_attempt_question"),
    )

    op.create_table(
        "wrong_questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("student_profile_id", sa.Integer(), sa.ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("paper_id", sa.Integer(), sa.ForeignKey("papers.id"), nullable=False),
        sa.Column("question_id", sa.Integer(), sa.ForeignKey("paper_questions.id"), nullable=False),
        sa.Column("subject", sa.String(20), nullable=False),
        sa.Column("knowledge_point", sa.String(100), nullable=False),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("user_answer", sa.Text(), nullable=False),
        sa.Column("correct_answer", sa.Text(), nullable=False),
        sa.Column("explanation", sa.Text(), nullable=False),
        sa.Column("mastered", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("wrong_count", sa.Integer(), nullable=False, server_default="1"),
        *timestamp_columns(),
        sa.UniqueConstraint("student_profile_id", "question_id", name="uq_student_wrong_question"),
    )
    op.create_index("ix_wrong_questions_student_profile_id", "wrong_questions", ["student_profile_id"])
    op.create_index("ix_wrong_questions_subject", "wrong_questions", ["subject"])

    op.create_table(
        "rag_documents",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("source_id", sa.String(100), nullable=False),
        sa.Column("source_type", sa.String(30), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("content_hash", sa.String(64), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        *timestamp_columns(),
        sa.UniqueConstraint("source_type", "source_id", "content_hash", name="uq_rag_document_source_hash"),
    )
    op.create_index("ix_rag_documents_source_id", "rag_documents", ["source_id"])
    op.create_index("ix_rag_documents_source_type", "rag_documents", ["source_type"])
    op.create_index("ix_rag_documents_content_hash", "rag_documents", ["content_hash"])

    op.create_table(
        "rag_chunks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("document_id", sa.Integer(), sa.ForeignKey("rag_documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("document_id", "chunk_index", name="uq_rag_document_chunk"),
    )
    op.create_index("ix_rag_chunks_document_id", "rag_chunks", ["document_id"])

    op.create_table(
        "ai_requests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("request_id", sa.String(64), nullable=False, unique=True),
        sa.Column("client_message_id", sa.String(64), nullable=False),
        sa.Column("session_id", sa.String(36), sa.ForeignKey("chat_sessions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("student_profile_id", sa.Integer(), sa.ForeignKey("student_profiles.id"), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="processing"),
        sa.Column("intent", sa.String(50), nullable=False, server_default="UNKNOWN"),
        sa.Column("response_json", sa.JSON(), nullable=True),
        sa.Column("error_code", sa.String(50), nullable=False, server_default=""),
        *timestamp_columns(),
        sa.UniqueConstraint("session_id", "client_message_id", name="uq_ai_session_client_message"),
    )
    op.create_index("ix_ai_requests_request_id", "ai_requests", ["request_id"])
    op.create_index("ix_ai_requests_session_id", "ai_requests", ["session_id"])


def downgrade() -> None:
    for table in (
        "ai_requests", "rag_chunks", "rag_documents", "wrong_questions", "practice_answers",
        "practice_attempts", "paper_questions", "course_enrollments", "course_orders",
    ):
        op.drop_table(table)
    op.drop_index("ix_tool_call_logs_request_id", table_name="tool_call_logs")
    for column in ("error_code", "status", "request_id"):
        op.drop_column("tool_call_logs", column)
    op.drop_index("ix_chat_messages_client_message_id", table_name="chat_messages")
    for column in ("model_metadata_json", "tool_calls_json", "client_message_id"):
        op.drop_column("chat_messages", column)
    for column in ("source_session_id", "knowledge_point", "duration_minutes", "scheduled_date"):
        op.drop_column("study_tasks", column)
    op.drop_column("courses", "total_lessons")
    op.drop_column("courses", "price")
