from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import JSON, Boolean, Date, DateTime, Float, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from server.database.session import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, onupdate=utc_now, nullable=False)


class User(TimestampMixin, Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default="parent")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Family(TimestampMixin, Base):
    __tablename__ = "families"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    invite_code: Mapped[str] = mapped_column(String(32), unique=True, index=True)


class FamilyMember(TimestampMixin, Base):
    __tablename__ = "family_members"
    __table_args__ = (UniqueConstraint("family_id", "user_id", name="uq_family_user"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    family_id: Mapped[int] = mapped_column(ForeignKey("families.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    family_role: Mapped[str] = mapped_column(String(20))


class StudentProfile(TimestampMixin, Base):
    __tablename__ = "student_profiles"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    family_id: Mapped[int] = mapped_column(ForeignKey("families.id", ondelete="CASCADE"), index=True)
    student_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, unique=True)
    name: Mapped[str] = mapped_column(String(50))
    grade: Mapped[str] = mapped_column(String(20))
    learning_goal: Mapped[str] = mapped_column(String(100))
    weekly_study_minutes: Mapped[int] = mapped_column(Integer, default=180)
    bind_code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    bind_code_used: Mapped[bool] = mapped_column(Boolean, default=False)
    profile_completed: Mapped[bool] = mapped_column(Boolean, default=False)


class StudentSubjectProfile(TimestampMixin, Base):
    __tablename__ = "student_subject_profiles"
    __table_args__ = (UniqueConstraint("student_profile_id", "subject", name="uq_student_subject"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    subject: Mapped[str] = mapped_column(String(20))
    recent_score: Mapped[float] = mapped_column(Float)
    weak_points: Mapped[list[str]] = mapped_column(JSON, default=list)


class Course(TimestampMixin, Base):
    __tablename__ = "courses"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(150), unique=True)
    grade: Mapped[str] = mapped_column(String(20), index=True)
    subject: Mapped[str] = mapped_column(String(20), index=True)
    level: Mapped[str] = mapped_column(String(30), index=True)
    difficulty: Mapped[str] = mapped_column(String(20))
    suitable_for: Mapped[str] = mapped_column(Text)
    knowledge_points: Mapped[list[str]] = mapped_column(JSON, default=list)
    description: Mapped[str] = mapped_column(Text)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("99.00"))
    total_lessons: Mapped[int] = mapped_column(Integer, default=12)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Paper(TimestampMixin, Base):
    __tablename__ = "papers"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(150), unique=True)
    grade: Mapped[str] = mapped_column(String(20), index=True)
    subject: Mapped[str] = mapped_column(String(20), index=True)
    difficulty: Mapped[str] = mapped_column(String(20), index=True)
    knowledge_points: Mapped[list[str]] = mapped_column(JSON, default=list)
    question_count: Mapped[int] = mapped_column(Integer)
    suitable_course_level: Mapped[str] = mapped_column(String(30))
    source_url: Mapped[str] = mapped_column(String(255), default="")
    ocr_text: Mapped[str] = mapped_column(Text, default="")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_ai_generated: Mapped[bool] = mapped_column(Boolean, default=False)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)


class StudyTask(TimestampMixin, Base):
    __tablename__ = "study_tasks"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    creator_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    task_type: Mapped[str] = mapped_column(String(20))
    target_id: Mapped[int] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(150))
    subject: Mapped[str] = mapped_column(String(20))
    difficulty: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20), default="未开始")
    scheduled_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=40)
    knowledge_point: Mapped[str] = mapped_column(String(100), default="")
    source_session_id: Mapped[str | None] = mapped_column(String(36), nullable=True)


class ChatSession(TimestampMixin, Base):
    __tablename__ = "chat_sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(100), default="学习咨询")
    summary: Mapped[str] = mapped_column(Text, default="")
    context_json: Mapped[dict] = mapped_column(JSON, default=dict)


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("chat_sessions.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(20))
    content: Mapped[str] = mapped_column(Text)
    intent: Mapped[str] = mapped_column(String(50), default="GENERAL_CHAT")
    client_message_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    tool_calls_json: Mapped[list] = mapped_column(JSON, default=list)
    model_metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class RecommendationRecord(Base):
    __tablename__ = "recommendation_records"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id"), index=True)
    session_id: Mapped[str | None] = mapped_column(ForeignKey("chat_sessions.id"), nullable=True)
    recommendation_type: Mapped[str] = mapped_column(String(30))
    rule_result: Mapped[dict] = mapped_column(JSON)
    result_json: Mapped[dict] = mapped_column(JSON)
    explanation: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class ToolCallLog(Base):
    __tablename__ = "tool_call_logs"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_id: Mapped[str | None] = mapped_column(ForeignKey("chat_sessions.id"), nullable=True, index=True)
    tool_name: Mapped[str] = mapped_column(String(60))
    arguments_json: Mapped[dict] = mapped_column(JSON)
    success: Mapped[bool] = mapped_column(Boolean)
    duration_ms: Mapped[int] = mapped_column(Integer)
    error_summary: Mapped[str] = mapped_column(String(255), default="")
    request_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    status: Mapped[str] = mapped_column(String(20), default="completed")
    error_code: Mapped[str] = mapped_column(String(50), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class CourseOrder(TimestampMixin, Base):
    __tablename__ = "course_orders"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_no: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id"), index=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    status: Mapped[str] = mapped_column(String(20), default="PENDING", index=True)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class CourseEnrollment(TimestampMixin, Base):
    __tablename__ = "course_enrollments"
    __table_args__ = (UniqueConstraint("student_profile_id", "course_id", name="uq_student_course"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"), index=True)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("course_orders.id"), unique=True, nullable=True)
    completed_lessons: Mapped[int] = mapped_column(Integer, default=0)
    total_lessons: Mapped[int] = mapped_column(Integer, default=12)
    progress: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default="LEARNING")
    next_lesson: Mapped[str] = mapped_column(String(150), default="第一课")


class Favorite(TimestampMixin, Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("student_profile_id", "target_id", "type", name="uq_student_favorite"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    target_id: Mapped[int] = mapped_column(Integer, index=True)
    type: Mapped[str] = mapped_column(String(20), index=True)
    title: Mapped[str] = mapped_column(String(150))
    subtitle: Mapped[str] = mapped_column(String(150), default="")
    tag: Mapped[str] = mapped_column(String(50), default="")


class PaperQuestion(TimestampMixin, Base):
    __tablename__ = "paper_questions"
    __table_args__ = (
        UniqueConstraint("paper_id", "sequence", name="uq_paper_question_sequence"),
        UniqueConstraint("question_no", name="uq_paper_question_no"),
    )
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    paper_id: Mapped[int] = mapped_column(ForeignKey("papers.id", ondelete="CASCADE"), index=True)
    sequence: Mapped[int] = mapped_column(Integer)
    question_no: Mapped[int] = mapped_column(Integer, index=True, unique=True)
    stem: Mapped[str] = mapped_column(Text)
    options_json: Mapped[list[str]] = mapped_column(JSON, default=list)
    correct_index: Mapped[int] = mapped_column(Integer)
    explanation: Mapped[str] = mapped_column(Text, default="")
    knowledge_point: Mapped[str] = mapped_column(String(100), default="")


class PracticeAttempt(TimestampMixin, Base):
    __tablename__ = "practice_attempts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    paper_id: Mapped[int] = mapped_column(ForeignKey("papers.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    score: Mapped[float] = mapped_column(Float)
    correct_count: Mapped[int] = mapped_column(Integer)
    question_count: Mapped[int] = mapped_column(Integer)
    knowledge_stats_json: Mapped[dict] = mapped_column(JSON, default=dict)
    submitted_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class PracticeAnswer(Base):
    __tablename__ = "practice_answers"
    __table_args__ = (UniqueConstraint("attempt_id", "question_id", name="uq_attempt_question"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    attempt_id: Mapped[int] = mapped_column(ForeignKey("practice_attempts.id", ondelete="CASCADE"), index=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("paper_questions.id"), index=True)
    selected_index: Mapped[int] = mapped_column(Integer)
    correct: Mapped[bool] = mapped_column(Boolean)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class WrongQuestion(TimestampMixin, Base):
    __tablename__ = "wrong_questions"
    __table_args__ = (UniqueConstraint("student_profile_id", "question_id", name="uq_student_wrong_question"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id", ondelete="CASCADE"), index=True)
    paper_id: Mapped[int] = mapped_column(ForeignKey("papers.id"), index=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("paper_questions.id"), index=True)
    question_no: Mapped[int] = mapped_column(Integer, default=0, index=True)
    subject: Mapped[str] = mapped_column(String(20), index=True)
    knowledge_point: Mapped[str] = mapped_column(String(100), index=True)
    question_text: Mapped[str] = mapped_column(Text)
    user_answer: Mapped[str] = mapped_column(Text)
    correct_answer: Mapped[str] = mapped_column(Text)
    explanation: Mapped[str] = mapped_column(Text, default="")
    mastered: Mapped[bool] = mapped_column(Boolean, default=False)
    wrong_count: Mapped[int] = mapped_column(Integer, default=1)


class RagDocument(TimestampMixin, Base):
    __tablename__ = "rag_documents"
    __table_args__ = (UniqueConstraint("source_type", "source_id", "content_hash", name="uq_rag_document_source_hash"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    source_id: Mapped[str] = mapped_column(String(100), index=True)
    source_type: Mapped[str] = mapped_column(String(30), index=True)
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str] = mapped_column(Text)
    content_hash: Mapped[str] = mapped_column(String(64), index=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)


class RagChunk(Base):
    __tablename__ = "rag_chunks"
    __table_args__ = (UniqueConstraint("document_id", "chunk_index", name="uq_rag_document_chunk"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    document_id: Mapped[int] = mapped_column(ForeignKey("rag_documents.id", ondelete="CASCADE"), index=True)
    chunk_index: Mapped[int] = mapped_column(Integer)
    content: Mapped[str] = mapped_column(Text)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class AIRequest(TimestampMixin, Base):
    __tablename__ = "ai_requests"
    __table_args__ = (UniqueConstraint("session_id", "client_message_id", name="uq_ai_session_client_message"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    request_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    client_message_id: Mapped[str] = mapped_column(String(64))
    session_id: Mapped[str] = mapped_column(ForeignKey("chat_sessions.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    student_profile_id: Mapped[int] = mapped_column(ForeignKey("student_profiles.id"), index=True)
    status: Mapped[str] = mapped_column(String(20), default="processing")
    intent: Mapped[str] = mapped_column(String(50), default="UNKNOWN")
    response_json: Mapped[dict] = mapped_column(JSON, default=dict)
    error_code: Mapped[str] = mapped_column(String(50), default="")
