from typing import Any, Literal

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator


class RegisterRequest(BaseModel):
    username: str = Field(min_length=2, max_length=50)
    phone: str = Field(min_length=6, max_length=20)
    password: str = Field(min_length=6, max_length=128)
    role: Literal["parent", "student"] = "parent"


class LoginRequest(BaseModel):
    account: str
    password: str


class FamilyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class BindStudentRequest(BaseModel):
    bind_code: str = Field(min_length=4, max_length=32)


class StudentCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    grade: Literal["五年级", "六年级"]
    subject: Literal["数学", "英语"]
    recent_score: float = Field(ge=0, le=100)
    weak_points: list[str] = Field(default_factory=list, max_length=10)
    learning_goal: str = Field(min_length=1, max_length=100)
    weekly_study_minutes: int = Field(ge=30, le=2000)


class StudentUpdate(StudentCreate):
    pass


class RecommendationRequest(BaseModel):
    student_profile_id: int
    subject: str | None = None


class PaperAnalyzeRequest(BaseModel):
    text: str = Field(min_length=1, max_length=20000)
    grade: str | None = None


class StudyTaskCreate(BaseModel):
    student_profile_id: int
    task_type: Literal["课程", "试卷"]
    target_id: int


class TaskStatusUpdate(BaseModel):
    status: Literal["未开始", "学习中", "已完成"]


class ChatRequest(BaseModel):
    session_id: str | None = None
    student_profile_id: int
    message: str = Field(min_length=1, max_length=2000)

    @field_validator("message")
    @classmethod
    def message_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("message cannot be blank")
        return value


class AIChatRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    session_id: str | None = Field(default=None, validation_alias=AliasChoices("sessionId", "session_id"))
    user_id: int | None = Field(default=None, validation_alias=AliasChoices("userId", "user_id"))
    student_profile_id: int = Field(validation_alias=AliasChoices("studentId", "studentProfileId", "student_profile_id"))
    client_message_id: str | None = Field(default=None, validation_alias=AliasChoices("clientMessageId", "client_message_id"))
    message: str = Field(min_length=1, max_length=2000)

    @field_validator("message")
    @classmethod
    def ai_message_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("message cannot be blank")
        return value


class OrderCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    student_profile_id: int = Field(validation_alias=AliasChoices("studentProfileId", "student_profile_id"))
    course_id: int = Field(validation_alias=AliasChoices("courseId", "course_id"))


class PracticeAnswerInput(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    question_id: int = Field(validation_alias=AliasChoices("questionId", "question_id"))
    selected_index: int = Field(ge=0, validation_alias=AliasChoices("selectedIndex", "selected_index"))


class PracticeAttemptCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    student_profile_id: int = Field(validation_alias=AliasChoices("studentProfileId", "student_profile_id"))
    answers: list[PracticeAnswerInput] = Field(min_length=1, max_length=100)


class WrongQuestionMasteryUpdate(BaseModel):
    mastered: bool = True


class ApiEnvelope(BaseModel):
    code: int = 0
    message: str = "success"
    data: Any = None
    requestId: str
