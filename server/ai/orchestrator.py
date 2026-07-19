import json
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai.intent import IntentClassifier, IntentResult, IntentType
from server.ai.memory import ConversationMemoryService
from server.ai.providers import ProviderError, ProviderRouter
from server.ai.rag import RAGService
from server.models import AIRequest, ChatMessage, ChatSession, StudentSubjectProfile, User
from server.services.access_service import ensure_student_access
from server.services.learning_service import my_courses
from server.tools import (
    CourseRecommendTool,
    CourseSearchTool,
    LearningReportTool,
    OrderTool,
    PaperSearchTool,
    StudentProfileTool,
    StudyPlanTool,
    ToolContext,
    ToolRegistry,
    WrongQuestionTool,
)


SYSTEM_PROMPT = """你是智学规划助手，面向中小学生和家长。
只能依据工具结果和检索资料回答，不得虚构课程、试卷、价格、成绩、订单状态或统计数字。
不要输出内部思维过程。回答应简洁、友好，明确说明推荐依据和下一步操作。
当资料不足时承认不足；教育建议仅供辅助参考。"""


@dataclass(slots=True)
class PreparedChat:
    request: AIRequest
    session: ChatSession
    intent: IntentResult
    tool_calls: list[dict[str, Any]]
    cards: list[dict[str, Any]]
    sources: list[dict[str, Any]]
    facts: dict[str, Any]
    fallback_answer: str
    history: list[dict[str, str]]


def _course_cards(courses: list[dict]) -> list[dict]:
    return [{
        "type": "COURSE",
        "id": item["id"],
        "title": item["name"],
        "subtitle": f"{item.get('grade', '')} {item.get('subject', '')} {item.get('level', '')}".strip(),
        "price": item.get("price"),
        "route": "CourseDetailPage",
        "routeParams": {"id": item["id"]},
    } for item in courses]


def _paper_cards(papers: list[dict]) -> list[dict]:
    return [{
        "type": "PAPER",
        "id": item["id"],
        "title": item["name"],
        "subtitle": f"{item.get('grade', '')} {item.get('subject', '')} {item.get('difficulty', '')}".strip(),
        "route": "PaperDetailPage",
        "routeParams": {"id": item["id"]},
    } for item in papers]


def _fallback_answer(intent: IntentType, facts: dict[str, Any], clarification: str | None) -> str:
    if clarification:
        return clarification
    if intent == IntentType.COURSE_RECOMMENDATION:
        recommendation = facts.get("recommendation") or {}
        return recommendation.get("explanation") or "暂时没有找到匹配课程，请先完善学生档案。"
    if intent == IntentType.COURSE_SEARCH:
        count = len(facts.get("courses") or [])
        return f"已根据条件找到 {count} 门课程。" if count else "暂时没有找到符合条件的课程，可以调整年级或学科后重试。"
    if intent == IntentType.PAPER_SEARCH:
        count = len(facts.get("papers") or [])
        return f"已找到 {count} 份匹配试卷，可从卡片进入详情或开始练习。" if count else "暂时没有找到匹配试卷，可以放宽难度或知识点条件。"
    if intent == IntentType.STUDY_PLAN_GENERATION:
        plan = facts.get("studyPlan") or {}
        return f"已生成 {plan.get('taskCount', 0)} 项七天学习任务，可以在学习计划中查看。"
    if intent in {IntentType.LEARNING_REPORT, IntentType.LEARNING_ANALYSIS}:
        report = facts.get("learningReport") or {}
        return report.get("aiSuggestion") or "当前学习记录较少，完成课程和试卷后会生成更准确的学情分析。"
    if intent == IntentType.WRONG_QUESTION_ANALYSIS:
        points = facts.get("frequentKnowledgePoints") or []
        return f"当前高频薄弱点是{'、'.join(points)}，建议优先进行专项复习。" if points else "当前没有未掌握错题，继续保持并定期复盘。"
    if intent == IntentType.ORDER_CREATION:
        if facts.get("confirmationRequired"):
            return str(facts.get("message"))
        order = facts.get("order") or {}
        return f"已创建待支付订单 {order.get('orderNo', '')}，请在订单页面确认；系统不会自动支付。"
    if intent == IntentType.MY_COURSES:
        return f"当前共有 {len(facts.get('courses') or [])} 门已报名课程。"
    if intent == IntentType.MY_ORDERS:
        return f"当前查询到 {len(facts.get('orders') or [])} 条订单记录。"
    if intent == IntentType.UNKNOWN:
        return "我还没有理解这个问题。你可以咨询课程推荐、试卷、学习计划、错题或学习报告。"
    return "我可以结合学生档案、课程、试卷和学习记录提供建议。你也可以告诉我年级、学科和具体困难。"


class AIOrchestrator:
    def __init__(self, db: AsyncSession, user: User):
        self.db = db
        self.user = user
        self.provider = ProviderRouter()
        self.memory = ConversationMemoryService(db, user)

    async def _register_tools(self, session: ChatSession, request_id: str, student) -> ToolRegistry:
        context = ToolContext(self.db, self.user, student, session.id, request_id)
        registry = ToolRegistry(self.db, session.id, request_id, context)
        for tool in (
            StudentProfileTool(),
            CourseRecommendTool(),
            CourseSearchTool(),
            PaperSearchTool(),
            StudyPlanTool(),
            LearningReportTool(),
            WrongQuestionTool(),
            OrderTool(),
        ):
            registry.register_tool(tool)
        return registry

    async def _execute(self, registry: ToolRegistry, intent: IntentResult, message: str) -> tuple[list[dict], dict, list[dict]]:
        calls: list[dict] = []
        facts: dict[str, Any] = {}
        cards: list[dict[str, Any]] = []

        async def call(name: str, arguments: dict[str, Any]) -> dict:
            result = await registry.execute(name, arguments)
            calls.append({"name": name, "arguments": arguments, "result": result})
            return result

        entities = intent.extracted_entities
        if intent.intent == IntentType.COURSE_RECOMMENDATION:
            await call("student_profile_tool", {"subject": entities.get("subject")})
            result = await call("course_recommend_tool", {"subject": entities["subject"]})
            recommendation = result.get("recommendation") or {}
            facts.update(recommendation)
            facts["recommendation"] = recommendation
            cards.extend(_course_cards(recommendation.get("courses") or []))
            cards.extend(_paper_cards(recommendation.get("papers") or []))
        elif intent.intent == IntentType.COURSE_SEARCH:
            result = await call("course_search_tool", entities)
            facts.update(result)
            cards.extend(_course_cards(result.get("courses") or []))
        elif intent.intent == IntentType.PAPER_SEARCH:
            result = await call("paper_search_tool", entities)
            facts.update(result)
            cards.extend(_paper_cards(result.get("papers") or []))
        elif intent.intent == IntentType.STUDY_PLAN_GENERATION:
            result = await call("study_plan_tool", {})
            facts.update(result)
            plan = result.get("studyPlan") or {}
            cards.append({"type": "STUDY_PLAN", "id": plan.get("planId"), "title": plan.get("title", "一周学习计划"),
                          "subtitle": f"共 {plan.get('taskCount', 0)} 项任务", "route": "StudyPlanPage", "routeParams": {}})
        elif intent.intent == IntentType.LEARNING_ANALYSIS:
            facts.update(await call("student_profile_tool", {"subject": entities.get("subject")}))
            facts.update(await call("learning_report_tool", {}))
        elif intent.intent == IntentType.LEARNING_REPORT:
            facts.update(await call("learning_report_tool", {}))
        elif intent.intent == IntentType.WRONG_QUESTION_ANALYSIS:
            facts.update(await call("wrong_question_tool", {"subject": entities.get("subject")}))
        elif intent.intent == IntentType.ORDER_CREATION:
            confirmed = any(word in message for word in ("确认报名", "创建订单", "立即报名", "生成订单"))
            result = await call("order_tool", {"action": "create", "courseId": entities.get("courseId"), "confirmed": confirmed})
            facts.update(result)
            order = result.get("order")
            if order:
                cards.append({"type": "ORDER", "id": order["id"], "title": order.get("courseName", "课程订单"),
                              "subtitle": f"{order['status']} · ¥{order['amount']:.2f}", "route": "OrderDetailPage",
                              "routeParams": {"id": order["id"]}})
        elif intent.intent == IntentType.MY_COURSES:
            facts["courses"] = await my_courses(self.db, self.user, registry.context.student.id if registry.context else None)
            cards.extend(_course_cards([{**item, "id": item["courseId"]} for item in facts["courses"]]))
        elif intent.intent == IntentType.MY_ORDERS:
            facts.update(await call("order_tool", {"action": "list", "orderStatus": entities.get("orderStatus")}))
        return calls, facts, cards

    async def prepare(
        self,
        student_profile_id: int,
        message: str,
        session_id: str | None = None,
        client_message_id: str | None = None,
        requested_user_id: int | None = None,
    ) -> PreparedChat | dict:
        if requested_user_id is not None and requested_user_id != self.user.id:
            raise HTTPException(status_code=403, detail="userId 与当前登录用户不一致")
        student = await ensure_student_access(self.db, self.user, student_profile_id)
        session = await self.memory.get_or_create(student.id, session_id)
        client_id = client_message_id or str(uuid4())
        existing = await self.db.scalar(select(AIRequest).where(
            AIRequest.session_id == session.id,
            AIRequest.client_message_id == client_id,
        ))
        if existing and existing.status == "completed" and existing.response_json:
            return existing.response_json

        if existing and existing.status in {"prepared", "failed"} and existing.response_json.get("fallbackAnswer"):
            payload = existing.response_json
            recovered_intent = IntentResult(
                intent=IntentType(payload["intent"]),
                confidence=float(payload.get("confidence", 0.5)),
                extracted_entities=dict(session.context_json or {}),
                missing_fields=list(payload.get("missingFields") or []),
                clarification_question=payload.get("clarificationQuestion"),
            )
            existing.status = "prepared"
            existing.error_code = ""
            return PreparedChat(
                existing,
                session,
                recovered_intent,
                list(payload.get("toolCalls") or []),
                list(payload.get("cards") or []),
                list(payload.get("sources") or []),
                dict(payload.get("facts") or {}),
                str(payload["fallbackAnswer"]),
                await self.memory.recent_messages(session),
            )

        request = existing or AIRequest(
            request_id=str(uuid4()),
            client_message_id=client_id,
            session_id=session.id,
            user_id=self.user.id,
            student_profile_id=student.id,
            status="processing",
        )
        if existing is None:
            self.db.add(request)
            self.memory.add_message(session, "user", message, "UNKNOWN", client_id)
            await self.db.flush()

        context = dict(session.context_json or {})
        context.setdefault("studentId", student.id)
        context.setdefault("grade", student.grade)
        context.setdefault("learningGoal", student.learning_goal)
        subjects = list((await self.db.scalars(select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == student.id
        ))).all())
        preferred = next((item for item in subjects if item.subject in message), subjects[0] if subjects else None)
        if preferred:
            context.setdefault("subject", preferred.subject)
            context.setdefault("score", preferred.recent_score)
            context.setdefault("weakPoints", preferred.weak_points)

        intent = await IntentClassifier(self.provider).classify(message, context)
        session.context_json = intent.extracted_entities
        request.intent = intent.intent.value
        tool_calls: list[dict] = []
        facts: dict[str, Any] = {}
        cards: list[dict[str, Any]] = []
        if not intent.missing_fields:
            registry = await self._register_tools(session, request.request_id, student)
            tool_calls, facts, cards = await self._execute(registry, intent, message)
        sources = await RAGService(self.db).search(message)
        fallback = _fallback_answer(intent.intent, facts, intent.clarification_question)
        history = await self.memory.recent_messages(session)
        prepared_payload = {
            "intent": intent.intent.value,
            "confidence": intent.confidence,
            "missingFields": intent.missing_fields,
            "clarificationQuestion": intent.clarification_question,
            "toolCalls": tool_calls,
            "cards": cards,
            "sources": sources,
            "facts": facts,
            "fallbackAnswer": fallback,
        }
        request.status = "prepared"
        request.response_json = prepared_payload
        await self.db.flush()
        return PreparedChat(request, session, intent, tool_calls, cards, sources, facts, fallback, history)

    def _messages(self, prepared: PreparedChat, message: str) -> list[dict[str, str]]:
        evidence = json.dumps({"facts": prepared.facts, "sources": prepared.sources}, ensure_ascii=False)
        return [
            {"role": "system", "content": SYSTEM_PROMPT},
            *prepared.history,
            {"role": "user", "content": message},
            {"role": "system", "content": f"本轮可用事实与资料：{evidence}"},
        ]

    async def _complete(self, prepared: PreparedChat, message: str) -> dict:
        if prepared.intent.clarification_question:
            answer = prepared.fallback_answer
            model = "deterministic-clarification"
            fallback_used = False
            metadata: dict[str, Any] = {}
        else:
            result = await self.provider.complete(self._messages(prepared, message), fallback_content=prepared.fallback_answer)
            answer = result.content
            model = result.model
            fallback_used = result.fallback_used
            metadata = {"model": model, "usage": result.usage, "latencyMs": result.latency_ms, "fallbackUsed": fallback_used}
        response = {
            "sessionId": prepared.session.id,
            "intent": prepared.intent.intent.value,
            "confidence": prepared.intent.confidence,
            "answer": answer,
            "assistantMessage": answer,
            "missingFields": prepared.intent.missing_fields,
            "clarificationQuestion": prepared.intent.clarification_question,
            "toolCalls": prepared.tool_calls,
            "cards": prepared.cards,
            "sources": [{key: value for key, value in source.items() if key != "content"} | {"excerpt": source["content"][:180]} for source in prepared.sources],
            "fallbackUsed": fallback_used,
            "requestId": prepared.request.request_id,
            "recommendation": prepared.facts.get("recommendation"),
        }
        self.memory.add_message(prepared.session, "assistant", answer, prepared.intent.intent.value,
                                tool_calls=prepared.tool_calls, model_metadata=metadata)
        await self.memory.summarize_if_needed(prepared.session)
        prepared.request.status = "completed"
        prepared.request.response_json = response
        await self.db.commit()
        return response

    async def handle(
        self,
        student_profile_id: int,
        message: str,
        session_id: str | None = None,
        client_message_id: str | None = None,
        requested_user_id: int | None = None,
    ) -> dict:
        prepared = await self.prepare(student_profile_id, message, session_id, client_message_id, requested_user_id)
        if isinstance(prepared, dict):
            return prepared
        try:
            return await self._complete(prepared, message)
        except ProviderError as exc:
            prepared.request.status = "failed"
            prepared.request.error_code = exc.code
            await self.db.commit()
            raise HTTPException(status_code=503, detail=str(exc)) from exc

    async def stream(
        self,
        student_profile_id: int,
        message: str,
        session_id: str | None = None,
        client_message_id: str | None = None,
        requested_user_id: int | None = None,
    ) -> AsyncIterator[tuple[str, dict]]:
        prepared = await self.prepare(student_profile_id, message, session_id, client_message_id, requested_user_id)
        if isinstance(prepared, dict):
            yield "meta", {"sessionId": prepared["sessionId"], "requestId": prepared["requestId"], "replayed": True}
            yield "delta", {"content": prepared["answer"]}
            yield "done", prepared
            return
        yield "meta", {"sessionId": prepared.session.id, "requestId": prepared.request.request_id, "fallbackUsed": False}
        yield "intent", {"intent": prepared.intent.intent.value, "confidence": prepared.intent.confidence,
                          "missingFields": prepared.intent.missing_fields, "clarificationQuestion": prepared.intent.clarification_question}
        for call in prepared.tool_calls:
            yield "tool_start", {"name": call["name"], "arguments": call["arguments"]}
            yield "tool_result", {"name": call["name"], "result": call["result"]}
        for source in prepared.sources:
            yield "source", {key: value for key, value in source.items() if key != "content"} | {"excerpt": source["content"][:180]}

        chunks: list[str] = []
        if prepared.intent.clarification_question:
            chunks.append(prepared.fallback_answer)
            yield "delta", {"content": prepared.fallback_answer}
            model = "deterministic-clarification"
            fallback_used = False
        else:
            try:
                async for delta in self.provider.stream(self._messages(prepared, message), fallback_content=prepared.fallback_answer):
                    chunks.append(delta)
                    yield "delta", {"content": delta}
            except ProviderError as exc:
                prepared.request.status = "failed"
                prepared.request.error_code = exc.code
                await self.db.commit()
                yield "error", {"code": exc.code, "message": str(exc), "requestId": prepared.request.request_id}
                return
            model = self.provider.provider.model
            fallback_used = self.provider.provider.name == "mock" or not self.provider.configured
        answer = "".join(chunks).strip() or prepared.fallback_answer
        response = {
            "sessionId": prepared.session.id,
            "intent": prepared.intent.intent.value,
            "confidence": prepared.intent.confidence,
            "answer": answer,
            "assistantMessage": answer,
            "missingFields": prepared.intent.missing_fields,
            "clarificationQuestion": prepared.intent.clarification_question,
            "toolCalls": prepared.tool_calls,
            "cards": prepared.cards,
            "sources": [{key: value for key, value in source.items() if key != "content"} | {"excerpt": source["content"][:180]} for source in prepared.sources],
            "fallbackUsed": fallback_used,
            "requestId": prepared.request.request_id,
            "recommendation": prepared.facts.get("recommendation"),
        }
        self.memory.add_message(prepared.session, "assistant", answer, prepared.intent.intent.value,
                                tool_calls=prepared.tool_calls, model_metadata={"model": model, "fallbackUsed": fallback_used})
        await self.memory.summarize_if_needed(prepared.session)
        prepared.request.status = "completed"
        prepared.request.response_json = response
        await self.db.commit()
        yield "done", response


ChatOrchestrator = AIOrchestrator
