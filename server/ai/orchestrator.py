from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai.intent_service import classify_intent, extract_fields
from server.ai.model_client import MockModelClient
from server.config import get_settings
from server.models import ChatMessage, ChatSession, StudentSubjectProfile, User
from server.services.access_service import ensure_student_access
from server.services.recommendation_service import recommend_for_student
from server.tools import ToolRegistry


class ChatOrchestrator:
    def __init__(self, db: AsyncSession, user: User):
        self.db = db
        self.user = user
        self.model = MockModelClient()

    async def handle(self, student_profile_id: int, message: str, session_id: str | None = None) -> dict:
        profile = await ensure_student_access(self.db, self.user, student_profile_id)
        session = await self._get_or_create_session(profile.id, session_id)
        intent = classify_intent(message)
        context = extract_fields(message, session.context_json or {})
        subject_profile = await self.db.scalar(select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == profile.id,
            StudentSubjectProfile.subject == context.get("subject", "数学"),
        ))
        context.setdefault("grade", profile.grade)
        context.setdefault("learning_goal", profile.learning_goal)
        if subject_profile:
            context.setdefault("subject", subject_profile.subject)
            context.setdefault("score", subject_profile.recent_score)
            context.setdefault("weak_points", subject_profile.weak_points)
        session.context_json = context
        self.db.add(ChatMessage(session_id=session.id, role="user", content=message, intent=intent))

        missing = [field for field in ("grade", "subject", "score", "weak_points", "learning_goal") if not context.get(field)]
        tool_calls: list[dict] = []
        recommendation = None
        if intent == "COURSE_RECOMMENDATION" and missing:
            prompts = {
                "grade": "孩子当前是五年级还是六年级？", "subject": "需要咨询数学还是英语？",
                "score": "最近一次考试成绩大约多少分？", "weak_points": "主要薄弱知识点是什么？",
                "learning_goal": "学习目标是巩固基础、提高成绩还是竞赛拓展？",
            }
            answer = prompts[missing[0]]
        elif intent in {"COURSE_RECOMMENDATION", "STUDENT_ANALYSIS", "GENERAL_CHAT"}:
            registry = ToolRegistry(self.db, session.id)

            async def recommendation_tool(arguments: dict) -> dict:
                return await recommend_for_student(
                    self.db, self.user, profile, str(arguments.get("subject") or context["subject"]), session.id
                )

            registry.register("CourseRecommendationTool", recommendation_tool)
            tool_calls.append({"name": "CourseRecommendationTool", "arguments": {"subject": context.get("subject")}})
            tool_result = await registry.execute("CourseRecommendationTool", {"subject": context.get("subject")})
            recommendation = tool_result.get("recommendation")
            answer = await self.model.compose(intent, tool_result)
        elif intent == "PAPER_RECOMMENDATION":
            answer = "我已记录试卷推荐需求。请在试卷资源页按年级、科目和知识点筛选，课程推荐结果也会自动匹配三份试卷。"
        elif intent == "STUDY_PLAN":
            answer = "可以将课程或试卷加入学习计划，并由学生账号更新未开始、学习中和已完成状态。"
        else:
            answer = "我可以帮助分析学情、查询课程、推荐试卷和制定学习计划。"

        self.db.add(ChatMessage(session_id=session.id, role="assistant", content=answer, intent=intent))
        await self._summarize_if_needed(session)
        await self.db.commit()
        return {
            "sessionId": session.id,
            "assistantMessage": answer,
            "intent": intent,
            "missingFields": missing if intent == "COURSE_RECOMMENDATION" else [],
            "toolCalls": tool_calls,
            "recommendation": recommendation,
        }

    async def _get_or_create_session(self, student_profile_id: int, session_id: str | None) -> ChatSession:
        if session_id:
            session = await self.db.get(ChatSession, session_id)
            if session and session.user_id == self.user.id and session.student_profile_id == student_profile_id:
                return session
        session = ChatSession(id=str(uuid4()), user_id=self.user.id, student_profile_id=student_profile_id)
        self.db.add(session)
        await self.db.flush()
        return session

    async def _summarize_if_needed(self, session: ChatSession) -> None:
        limit = get_settings().max_chat_messages
        count = await self.db.scalar(select(func.count(ChatMessage.id)).where(ChatMessage.session_id == session.id))
        if count and count > limit:
            session.summary = f"已保留学生学情字段：{session.context_json}；完整历史共{count}条。"
