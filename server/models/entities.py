from datetime import datetime, timezone

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
