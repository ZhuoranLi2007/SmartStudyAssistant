from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any


class IntentType(StrEnum):
    COURSE_RECOMMENDATION = "COURSE_RECOMMENDATION"
    COURSE_SEARCH = "COURSE_SEARCH"
    PAPER_SEARCH = "PAPER_SEARCH"
    STUDY_PLAN_GENERATION = "STUDY_PLAN_GENERATION"
    LEARNING_ANALYSIS = "LEARNING_ANALYSIS"
    KNOWLEDGE_QA = "KNOWLEDGE_QA"
    LEARNING_REPORT = "LEARNING_REPORT"
    WRONG_QUESTION_ANALYSIS = "WRONG_QUESTION_ANALYSIS"
    ORDER_CREATION = "ORDER_CREATION"
    MY_COURSES = "MY_COURSES"
    MY_ORDERS = "MY_ORDERS"
    GENERAL_CHAT = "GENERAL_CHAT"
    UNKNOWN = "UNKNOWN"


@dataclass(slots=True)
class IntentResult:
    intent: IntentType
    confidence: float
    extracted_entities: dict[str, Any] = field(default_factory=dict)
    missing_fields: list[str] = field(default_factory=list)
    clarification_question: str | None = None
