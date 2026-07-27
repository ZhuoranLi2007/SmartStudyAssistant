import asyncio
import json
import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass
from time import perf_counter
from typing import Any
from uuid import uuid4

from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai.intent import IntentClassifier, IntentResult, IntentType, classify_by_rules
from server.ai.intent.intent_classifier import extract_entities
from server.ai.memory import ConversationMemoryService
from server.ai.providers import ProviderError, ProviderRouter
from server.models import AIRequest, ChatMessage, ChatSession, StudentSubjectProfile, User
from server.services.access_service import ensure_student_access
from server.services.learning_service import my_courses
from server.tools import (
    CourseRecommendTool,
    CourseSearchTool,
    KnowledgeSearchTool,
    LearningReportTool,
    OrderTool,
    PaperSearchTool,
    StudentProfileTool,
    StudyPlanTool,
    ToolContext,
    ToolRegistry,
    WrongQuestionTool,
)

logger = logging.getLogger("smartstudy.ai")


SYSTEM_PROMPT = """你是智学规划助手，面向中小学生和家长。
只能依据工具结果和检索资料回答，不得虚构课程、试卷、价格、成绩、订单状态或统计数字。
不要输出内部思维过程。回答应简洁、友好，明确说明推荐依据和下一步操作。
使用短段落、简单标题和单层列表；不要输出表格、HTML、代码块或复杂嵌套列表。
课程、试卷、计划和订单的详细字段由结构化卡片展示，正文不要重复抄写完整卡片内容。
用户本轮明确陈述的薄弱点属于当前对话事实，应与正式学生档案区分，不得声称已经自动修改档案。
如果用户重复询问同一问题，应结合历史回答继续深化、换一个分析角度或提出有价值的追问，不要机械重复上一轮措辞。
当资料不足时承认不足；教育建议仅供辅助参考。"""

AGENT_PROMPT = """你是智学规划助手的受控工具 Agent。根据用户本轮问题自主选择必要工具，不要凭空补充业务数据。
学生档案快照已经提供，不要再调用档案工具；涉及真实课程、试卷、计划、错题、报告或订单时必须调用相应工具。
用户陈述薄弱点或询问学习方法时，可调用知识检索工具获取匹配资料；不要为了凑数量调用无关工具。
查询工具可以直接调用。创建订单属于写操作：工具调用只表示拟执行动作，后端仍会要求用户二次确认。
每轮最多选择少量必要工具；工具报错时可修正参数重试一次。"""

MAX_AGENT_ROUNDS = 3
MAX_AGENT_TOOL_CALLS = 6
TOOL_TIMEOUT_SECONDS = 12.0
MAX_RECOMMENDATION_CARDS = 3
WRITE_TOOL_ACTIONS = {("order_tool", "create")}
CONFIRM_WORDS = ("确认", "同意报名", "确认报名", "确认创建")
CANCEL_WORDS = ("取消", "不确认", "不用了", "先不报名")

INTENT_TOOL_NAMES: dict[IntentType, set[str]] = {
    IntentType.COURSE_RECOMMENDATION: {"course_recommend_tool", "knowledge_search_tool"},
    IntentType.COURSE_SEARCH: {"course_search_tool"},
    IntentType.PAPER_SEARCH: {"paper_search_tool"},
    IntentType.STUDY_PLAN_GENERATION: {"study_plan_tool"},
    IntentType.LEARNING_ANALYSIS: {"learning_report_tool", "wrong_question_tool", "knowledge_search_tool"},
    IntentType.KNOWLEDGE_QA: {"knowledge_search_tool"},
    IntentType.LEARNING_REPORT: {"learning_report_tool"},
    IntentType.WRONG_QUESTION_ANALYSIS: {"wrong_question_tool", "knowledge_search_tool"},
    IntentType.ORDER_CREATION: {"order_tool"},
    IntentType.MY_ORDERS: {"order_tool"},
}

RESOURCE_TOOL_BY_INTENT: dict[IntentType, str] = {
    IntentType.COURSE_RECOMMENDATION: "course_recommend_tool",
    IntentType.COURSE_SEARCH: "course_search_tool",
    IntentType.PAPER_SEARCH: "paper_search_tool",
}


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


def _valid_resource_rows(items: list[dict], limit: int | None = MAX_RECOMMENDATION_CARDS) -> list[dict]:
    rows: list[dict] = []
    for item in items:
        resource_id = item.get("id")
        if isinstance(resource_id, bool) or not isinstance(resource_id, int) or resource_id <= 0:
            continue
        rows.append(item)
        if limit is not None and len(rows) >= limit:
            break
    return rows


def _course_cards(
    courses: list[dict],
    recommendation_reason: str = "",
    limit: int | None = MAX_RECOMMENDATION_CARDS,
) -> list[dict]:
    return [{
        "type": "COURSE",
        "id": item["id"],
        "title": item["name"],
        "subtitle": f"{item.get('grade', '')} {item.get('subject', '')} {item.get('level', '')}".strip(),
        "price": item.get("price"),
        "grade": item.get("grade", ""),
        "subject": item.get("subject", ""),
        "level": item.get("level", ""),
        "difficulty": item.get("difficulty", ""),
        "lessonCount": item.get("totalLessons"),
        "knowledgePoints": item.get("knowledgePoints") or [],
        "recommendationReason": recommendation_reason or item.get("suitableFor", ""),
        "route": "CourseDetailPage",
        "routeParams": {"id": item["id"]},
    } for item in _valid_resource_rows(courses, limit)]


def _paper_cards(
    papers: list[dict],
    limit: int | None = MAX_RECOMMENDATION_CARDS,
) -> list[dict]:
    return [{
        "type": "PAPER",
        "id": item["id"],
        "title": item["name"],
        "subtitle": f"{item.get('grade', '')} {item.get('subject', '')} {item.get('difficulty', '')}".strip(),
        "grade": item.get("grade", ""),
        "subject": item.get("subject", ""),
        "difficulty": item.get("difficulty", ""),
        "questionCount": item.get("questionCount"),
        "knowledgePoints": item.get("knowledgePoints") or [],
        "route": "PaperDetailPage",
        "routeParams": {"id": item["id"]},
    } for item in _valid_resource_rows(papers, limit)]


def _fallback_answer(intent: IntentType, facts: dict[str, Any], clarification: str | None) -> str:
    if clarification:
        return clarification
    if intent == IntentType.COURSE_RECOMMENDATION:
        recommendation = facts.get("recommendation") or {}
        if not _valid_resource_rows(recommendation.get("courses") or [], 1):
            return "暂时没有找到可打开的匹配课程，可以调整年级、学科或学习目标后重试。"
        return recommendation.get("explanation") or "已找到匹配课程，可从下方卡片进入课程详情。"
    if intent == IntentType.COURSE_SEARCH:
        count = len(_valid_resource_rows(facts.get("courses") or []))
        return f"已根据条件找到 {count} 门课程。" if count else "暂时没有找到符合条件的课程，可以调整年级或学科后重试。"
    if intent == IntentType.PAPER_SEARCH:
        count = len(_valid_resource_rows(facts.get("papers") or []))
        return f"已找到 {count} 份匹配试卷，可从卡片进入详情或开始练习。" if count else "暂时没有找到匹配试卷，可以放宽难度或知识点条件。"
    if intent == IntentType.STUDY_PLAN_GENERATION:
        plan = facts.get("studyPlan") or {}
        return f"已生成 {plan.get('taskCount', 0)} 项七天学习任务，可以在学习计划中查看。"
    if intent == IntentType.LEARNING_ANALYSIS and facts.get("reportedWeakPoints"):
        reported = list(facts["reportedWeakPoints"])
        point_text = "、".join(reported)
        profile = facts.get("studentProfile") or {}
        subjects = profile.get("subjects") or []
        subject_name = str(facts.get("reportedSubject") or "")
        subject = next((item for item in subjects if item.get("subject") == subject_name), subjects[0] if subjects else {})
        stored = list(subject.get("weakPoints") or [])
        stored_text = "、".join(stored) if stored else "暂未记录薄弱点"
        advice = {
            "应用题": "先从题干中标出已知条件和问题，再写出数量关系并分步列式；每天练习 3—5 道同类基础题，完成后复盘一道典型错题。",
            "百分数": "先区分单位“1”、百分率和对应数量，再用线段图或数量关系式检查列式；从基础题过渡到综合题。",
            "阅读": "先圈出题干关键词，再回到原文定位依据；每道错题记录是定位错误、理解偏差还是表达不完整。",
        }.get(reported[0], "先完成少量同类基础题，记录具体错误原因，再进行针对性复练和阶段检测。")
        return (
            f"收到，本轮先按“{point_text}比较弱”来分析。学生档案当前记录的是：{stored_text}；"
            f"本轮反馈只用于这次咨询，不会自动修改学生档案。\n\n建议：{advice}"
        )
    if intent in {IntentType.LEARNING_REPORT, IntentType.LEARNING_ANALYSIS}:
        report = facts.get("learningReport") or {}
        return report.get("aiSuggestion") or "当前学习记录较少，完成课程和试卷后会生成更准确的学情分析。"
    if intent == IntentType.WRONG_QUESTION_ANALYSIS:
        points = facts.get("frequentKnowledgePoints") or []
        return f"当前高频薄弱点是{'、'.join(points)}，建议优先进行专项复习。" if points else "当前没有未掌握错题，继续保持并定期复盘。"
    if intent == IntentType.ORDER_CREATION:
        if facts.get("confirmationCancelled") or facts.get("writeFailed"):
            return str(facts.get("message") or "本次订单操作未执行。")
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
    profile = facts.get("studentProfile") or {}
    subjects = profile.get("subjects") or []
    if profile:
        subject = subjects[0] if subjects else {}
        weak_points = subject.get("weakPoints") or []
        detail = f"{profile.get('name', '学生')}目前是{profile.get('grade', '')}"
        if subject:
            detail += f"，{subject.get('subject', '')}最近成绩为{subject.get('score', 0):g}分"
        if weak_points:
            detail += f"，薄弱点主要是{'、'.join(weak_points)}"
        return f"我已结合最新学生档案：{detail}。请告诉我想重点解决的学习问题，我会给出更具体的建议。"
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
        # Agent 只能通过白名单工具访问业务数据，模型本身不直接查询或修改数据库。
        for tool in (
            StudentProfileTool(),
            CourseRecommendTool(),
            CourseSearchTool(),
            PaperSearchTool(),
            StudyPlanTool(),
            LearningReportTool(),
            KnowledgeSearchTool(),
            WrongQuestionTool(),
            OrderTool(),
        ):
            registry.register_tool(tool)
        return registry

    async def _student_snapshot(self, student, message: str) -> tuple[dict[str, Any], dict[str, Any]]:
        subjects = list((await self.db.scalars(select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == student.id
        ).order_by(StudentSubjectProfile.updated_at.desc(), StudentSubjectProfile.id.desc()))).all())
        preferred = next((item for item in subjects if item.subject in message), subjects[0] if subjects else None)
        snapshot = {
            "studentId": student.id,
            "name": student.name,
            "grade": student.grade,
            "learningGoal": student.learning_goal,
            "weeklyStudyMinutes": student.weekly_study_minutes,
            "weeklyHours": round(student.weekly_study_minutes / 60, 1),
            "subjects": [{
                "subject": item.subject,
                "score": item.recent_score,
                "weakPoints": item.weak_points,
            } for item in subjects],
        }
        context = {
            "studentId": student.id,
            "studentName": student.name,
            "grade": student.grade,
            "learningGoal": student.learning_goal,
            "weeklyStudyMinutes": student.weekly_study_minutes,
            "allSubjects": snapshot["subjects"],
        }
        if preferred:
            context["subject"] = preferred.subject
            context["score"] = preferred.recent_score
            context["weakPoints"] = preferred.weak_points
        return snapshot, context

    @staticmethod
    def _cards_for_tool(name: str, result: dict[str, Any]) -> list[dict[str, Any]]:
        if name == "course_recommend_tool":
            recommendation = result.get("recommendation") or {}
            return _course_cards(recommendation.get("courses") or [], recommendation.get("explanation", ""))
        if name == "course_search_tool":
            return _course_cards(result.get("courses") or [])
        if name == "paper_search_tool":
            return _paper_cards(result.get("papers") or [])
        if name == "study_plan_tool":
            plan = result.get("studyPlan") or {}
            return [{
                "type": "STUDY_PLAN",
                "id": plan.get("planId") or 0,
                "title": plan.get("title", "一周学习计划"),
                "subtitle": f"共 {plan.get('taskCount', 0)} 项任务",
                "tasks": plan.get("tasks") or [],
                "route": "StudyPlanPage",
                "routeParams": {},
            }]
        if name == "order_tool" and result.get("order"):
            order = result["order"]
            return [{
                "type": "ORDER",
                "id": order["id"],
                "title": order.get("courseName", "课程订单"),
                "subtitle": f"{order['status']} · ¥{float(order['amount']):.2f}",
                "orderNo": order.get("orderNo", ""),
                "orderStatus": order.get("status", "PENDING"),
                "amount": float(order.get("amount", 0)),
                "route": "OrderDetailPage",
                "routeParams": {"id": order["id"]},
            }]
        return []

    @staticmethod
    def _merge_tool_result(name: str, result: dict[str, Any], facts: dict[str, Any]) -> list[dict[str, Any]]:
        if name == "knowledge_search_tool":
            return list(result.get("sources") or [])
        if name == "student_profile_tool":
            facts["studentProfile"] = result
        elif name == "course_recommend_tool":
            recommendation = result.get("recommendation") or {}
            facts["recommendation"] = recommendation
            facts.update(recommendation)
        else:
            facts.update(result)
        return []

    async def _execute_controlled_tool(
        self,
        registry: ToolRegistry,
        session: ChatSession,
        name: str,
        arguments: dict[str, Any],
        *,
        confirmed_write: bool = False,
    ) -> dict[str, Any]:
        action = str(arguments.get("action") or "")
        if (name, action) in WRITE_TOOL_ACTIONS and not confirmed_write:
            tool = registry.tools.get(name)
            if tool is None:
                raise ValueError(f"未注册工具: {name}")
            tool.validate(arguments)
            if not isinstance(arguments.get("courseId"), int):
                raise ValueError("创建订单需要有效 courseId")
            context = dict(session.context_json or {})
            context["pendingWrite"] = {
                "tool": name,
                "arguments": arguments,
                "requestId": registry.request_id,
            }
            session.context_json = context
            return {
                "confirmationRequired": True,
                "pendingAction": "CREATE_ORDER",
                "courseId": arguments.get("courseId"),
                "message": f"准备为课程 {arguments.get('courseId')} 创建待支付订单。请再次明确回复“确认报名”后执行。",
            }
        return await registry.execute(name, arguments)

    async def _run_agent_tools(
        self,
        registry: ToolRegistry,
        session: ChatSession,
        intent: IntentResult,
        message: str,
        history: list[dict[str, str]],
        student_snapshot: dict[str, Any],
    ) -> tuple[list[dict[str, Any]], dict[str, Any], list[dict[str, Any]], list[dict[str, Any]], bool]:
        facts: dict[str, Any] = {}
        cards: list[dict[str, Any]] = []
        sources: list[dict[str, Any]] = []
        calls: list[dict[str, Any]] = []
        allowed_names = set(INTENT_TOOL_NAMES.get(intent.intent, set()))
        reported_weak_points = [
            point for point in (intent.extracted_entities.get("weakPoints") or []) if point in message
        ]
        if intent.intent == IntentType.LEARNING_ANALYSIS and reported_weak_points:
            # 明确的薄弱点反馈只需要检索解题资料；档案快照已在上下文中，无需再查资源目录。
            allowed_names = {"knowledge_search_tool"}
        definitions = registry.provider_definitions(allowed_names)
        if not definitions:
            return calls, facts, cards, sources, False
        messages: list[dict[str, Any]] = [
            {"role": "system", "content": AGENT_PROMPT},
            *history,
            {"role": "system", "content": "已授权学生快照：" + json.dumps(student_snapshot, ensure_ascii=False)},
            {"role": "system", "content": f"当前主意图：{intent.intent.value}"},
            {"role": "user", "content": message},
        ]
        used_fallback = False
        cached_results: dict[str, dict[str, Any]] = {}
        model_tool_call_count = 0
        for round_index in range(MAX_AGENT_ROUNDS):
            started = perf_counter()
            result = await self.provider.complete(
                messages,
                tools=definitions,
                tool_choice="auto",
                temperature=0.1,
                max_tokens=800,
            )
            used_fallback = used_fallback or result.fallback_used
            logger.info(
                "AI stage request_id=%s stage=tool_selection round=%s latency_ms=%s tool_count=%s fallback=%s",
                registry.request_id,
                round_index + 1,
                int((perf_counter() - started) * 1000),
                len(result.tool_calls),
                result.fallback_used,
            )
            if not result.tool_calls:
                break
            allowed = result.tool_calls[:max(0, MAX_AGENT_TOOL_CALLS - model_tool_call_count)]
            model_tool_call_count += len(allowed)
            messages.append({
                "role": "assistant",
                "content": result.content or None,
                "tool_calls": [{
                    "id": call.id,
                    "type": "function",
                    "function": {"name": call.name, "arguments": json.dumps(call.arguments, ensure_ascii=False)},
                } for call in allowed],
            })
            round_added_facts = False
            for call in allowed:
                if call.name not in allowed_names:
                    tool_result = {"error": "TOOL_NOT_ALLOWED", "message": "当前意图不允许调用该工具"}
                    success = False
                    logger.warning(
                        "AI tool blocked request_id=%s intent=%s tool=%s",
                        registry.request_id,
                        intent.intent.value,
                        call.name,
                    )
                elif call.name in cached_results:
                    tool_result = cached_results[call.name]
                    success = True
                    logger.info(
                        "AI tool reused request_id=%s intent=%s tool=%s",
                        registry.request_id,
                        intent.intent.value,
                        call.name,
                    )
                else:
                    try:
                        async with self.db.begin_nested():
                            tool_result = await asyncio.wait_for(
                                self._execute_controlled_tool(registry, session, call.name, call.arguments),
                                timeout=TOOL_TIMEOUT_SECONDS,
                            )
                        success = True
                    except Exception as exc:
                        tool_result = {"error": exc.__class__.__name__, "message": str(exc)[:200]}
                        success = False
                        logger.warning(
                            "AI tool failed request_id=%s tool=%s error_type=%s",
                            registry.request_id,
                            call.name,
                            exc.__class__.__name__,
                        )
                safe_result = jsonable_encoder(tool_result)
                if success and call.name not in cached_results:
                    cached_results[call.name] = safe_result
                    calls.append({"name": call.name, "arguments": call.arguments, "result": safe_result, "success": True})
                    sources.extend(self._merge_tool_result(call.name, safe_result, facts))
                    cards.extend(self._cards_for_tool(call.name, safe_result))
                    round_added_facts = True
                elif not success:
                    calls.append({"name": call.name, "arguments": call.arguments, "result": safe_result, "success": False})
                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": json.dumps(safe_result, ensure_ascii=False),
                })
            if not round_added_facts or allowed_names.issubset(cached_results):
                break
            if model_tool_call_count >= MAX_AGENT_TOOL_CALLS:
                break
        return calls, facts, cards, sources, used_fallback

    @staticmethod
    def _pending_write_decision(session: ChatSession, message: str) -> tuple[str, dict[str, Any] | None]:
        context = dict(session.context_json or {})
        pending = context.get("pendingWrite")
        if not isinstance(pending, dict):
            return "none", None
        if any(word in message for word in CANCEL_WORDS):
            context.pop("pendingWrite", None)
            session.context_json = context
            return "cancel", pending
        if any(word in message for word in CONFIRM_WORDS):
            current_course = extract_entities(message).get("courseId")
            pending_course = (pending.get("arguments") or {}).get("courseId")
            if current_course and pending_course and current_course != pending_course:
                return "none", pending
            return "confirm", pending
        return "none", pending

    async def _execute(
        self,
        registry: ToolRegistry,
        session: ChatSession,
        intent: IntentResult,
        message: str,
    ) -> tuple[list[dict], dict, list[dict], list[dict]]:
        calls: list[dict] = []
        facts: dict[str, Any] = {}
        cards: list[dict[str, Any]] = []
        sources: list[dict[str, Any]] = []

        async def call(name: str, arguments: dict[str, Any]) -> dict:
            result = await asyncio.wait_for(
                self._execute_controlled_tool(registry, session, name, arguments),
                timeout=TOOL_TIMEOUT_SECONDS,
            )
            calls.append({"name": name, "arguments": arguments, "result": result})
            return result

        entities = intent.extracted_entities
        if intent.intent == IntentType.COURSE_RECOMMENDATION:
            facts["studentProfile"] = await call("student_profile_tool", {"subject": entities.get("subject")})
            result = await call("course_recommend_tool", {"subject": entities["subject"]})
            recommendation = result.get("recommendation") or {}
            facts.update(recommendation)
            facts["recommendation"] = recommendation
            cards.extend(_course_cards(recommendation.get("courses") or [], recommendation.get("explanation", "")))
        elif intent.intent == IntentType.COURSE_SEARCH:
            result = await call("course_search_tool", {
                key: entities[key]
                for key in ("grade", "subject", "courseLevel", "knowledgePoint", "maxPrice")
                if entities.get(key) is not None
            })
            facts.update(result)
            cards.extend(_course_cards(result.get("courses") or []))
        elif intent.intent == IntentType.PAPER_SEARCH:
            result = await call("paper_search_tool", {
                key: entities[key]
                for key in ("grade", "subject", "difficulty", "knowledgePoint")
                if entities.get(key) is not None
            })
            facts.update(result)
            cards.extend(_paper_cards(result.get("papers") or []))
        elif intent.intent == IntentType.STUDY_PLAN_GENERATION:
            result = await call("study_plan_tool", {})
            facts.update(result)
            plan = result.get("studyPlan") or {}
            cards.append({"type": "STUDY_PLAN", "id": plan.get("planId") or 0, "title": plan.get("title", "一周学习计划"),
                          "subtitle": f"共 {plan.get('taskCount', 0)} 项任务", "tasks": plan.get("tasks") or [],
                          "route": "StudyPlanPage", "routeParams": {}})
        elif intent.intent == IntentType.LEARNING_ANALYSIS:
            facts.update(await call("student_profile_tool", {"subject": entities.get("subject")}))
            facts.update(await call("learning_report_tool", {}))
            knowledge = await call("knowledge_search_tool", {
                "query": message,
                "subject": entities.get("subject"),
                "sourceTypes": ["knowledge", "course", "paper"],
            })
            sources.extend(knowledge.get("sources") or [])
        elif intent.intent == IntentType.KNOWLEDGE_QA:
            knowledge = await call("knowledge_search_tool", {
                "query": message,
                "subject": entities.get("subject"),
                "sourceTypes": ["knowledge", "course", "paper"],
            })
            sources.extend(knowledge.get("sources") or [])
        elif intent.intent == IntentType.LEARNING_REPORT:
            facts.update(await call("learning_report_tool", {}))
        elif intent.intent == IntentType.WRONG_QUESTION_ANALYSIS:
            facts.update(await call("wrong_question_tool", {"subject": entities.get("subject")}))
        elif intent.intent == IntentType.ORDER_CREATION:
            result = await call("order_tool", {"action": "create", "courseId": entities.get("courseId")})
            facts.update(result)
            order = result.get("order")
            if order:
                cards.append({"type": "ORDER", "id": order["id"], "title": order.get("courseName", "课程订单"),
                              "subtitle": f"{order['status']} · ¥{order['amount']:.2f}", "orderNo": order.get("orderNo", ""),
                              "orderStatus": order.get("status", "PENDING"), "amount": float(order.get("amount", 0)),
                              "route": "OrderDetailPage",
                              "routeParams": {"id": order["id"]}})
        elif intent.intent == IntentType.MY_COURSES:
            facts["courses"] = await my_courses(self.db, self.user, registry.context.student.id if registry.context else None)
            cards.extend(_course_cards(
                [{**item, "id": item["courseId"]} for item in facts["courses"]],
                limit=None,
            ))
        elif intent.intent == IntentType.MY_ORDERS:
            facts.update(await call("order_tool", {"action": "list", "orderStatus": entities.get("orderStatus")}))
        return calls, facts, cards, sources

    async def prepare(
        self,
        student_profile_id: int,
        message: str,
        session_id: str | None = None,
        client_message_id: str | None = None,
        requested_user_id: int | None = None,
        message_saved_queue: asyncio.Queue[dict] | None = None,
    ) -> PreparedChat | dict:
        if requested_user_id is not None and requested_user_id != self.user.id:
            raise HTTPException(status_code=403, detail="userId 与当前登录用户不一致")
        student = await ensure_student_access(self.db, self.user, student_profile_id)
        session = await self.memory.get_or_create(student.id, session_id)
        active_session_id = session.id
        client_id = client_message_id or str(uuid4())
        existing = await self.db.scalar(select(AIRequest).where(
            AIRequest.session_id == active_session_id,
            AIRequest.client_message_id == client_id,
        ))
        # client_message_id 同时覆盖普通请求与 SSE 降级，重试不得重复创建订单或对话记录。
        if existing and existing.status == "completed" and existing.response_json:
            return existing.response_json

        if existing and existing.status == "processing":
            # 相同 clientMessageId 的并发请求只能有一个执行 Agent；其余请求等待并复用已提交结果。
            still_processing = True
            for _ in range(120):
                await asyncio.sleep(0.25)
                await self.db.rollback()
                current = await self.db.scalar(select(AIRequest).where(
                    AIRequest.session_id == active_session_id,
                    AIRequest.client_message_id == client_id,
                ))
                if current is not None and current.status == "completed" and current.response_json:
                    return current.response_json
                if current is not None and current.status in {"prepared", "failed"}:
                    existing = current
                    still_processing = False
                    break
            if still_processing:
                raise HTTPException(status_code=409, detail="相同消息正在另一台设备处理中，请稍后重试")

        if existing and existing.status in {"prepared", "failed"} and existing.response_json.get("fallbackAnswer"):
            payload = existing.response_json
            recovered_history = await self.memory.recent_messages(session)
            if recovered_history and recovered_history[-1].get("role") == "user" and recovered_history[-1].get("content") == message:
                recovered_history = recovered_history[:-1]
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
                recovered_history,
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
            user_message = self.memory.add_message(session, "user", message, "UNKNOWN", client_id)
            try:
                await self.db.flush()
                # 用户消息先独立提交，远端设备不必等待工具调用和最终回答即可读取提问。
                await self.db.commit()
            except IntegrityError:
                # 两台设备可能同时重试相同消息；唯一约束选出一个执行者，其余请求等待并复用结果。
                await self.db.rollback()
                for _ in range(120):
                    conflict = await self.db.scalar(select(AIRequest).where(
                        AIRequest.session_id == active_session_id,
                        AIRequest.client_message_id == client_id,
                    ))
                    if conflict is not None and conflict.status == "completed" and conflict.response_json:
                        return conflict.response_json
                    if conflict is not None and conflict.status in {"prepared", "failed"}:
                        return await self.prepare(
                            student_profile_id, message, active_session_id, client_id, requested_user_id,
                            message_saved_queue,
                        )
                    await self.db.rollback()
                    await asyncio.sleep(0.25)
                raise HTTPException(status_code=409, detail="相同消息正在另一台设备处理中，请稍后重试")
            if message_saved_queue is not None:
                await message_saved_queue.put({
                    "sessionId": session.id,
                    "messageId": user_message.id,
                    "clientMessageId": client_id,
                    "created": True,
                    "updatedAt": session.updated_at.isoformat(),
                })

        student_snapshot, latest_context = await self._student_snapshot(student, message)
        context = dict(session.context_json or {})
        context.update(latest_context)

        pending_decision, pending_write = self._pending_write_decision(session, message)
        intent_started = perf_counter()
        if pending_decision in {"confirm", "cancel"}:
            pending_arguments = dict((pending_write or {}).get("arguments") or {})
            intent = IntentResult(
                intent=IntentType.ORDER_CREATION,
                confidence=1.0,
                extracted_entities={**extract_entities(message, context), **pending_arguments},
            )
        else:
            try:
                intent = await IntentClassifier(self.provider).classify(message, context)
            except Exception as exc:
                logger.warning(
                    "AI intent fallback request_id=%s error_type=%s",
                    request.request_id,
                    exc.__class__.__name__,
                )
                intent = classify_by_rules(message, context)
        logger.info(
            "AI stage request_id=%s stage=intent intent=%s latency_ms=%s fallback=%s",
            request.request_id,
            intent.intent.value,
            int((perf_counter() - intent_started) * 1000),
            self.provider.provider.name == "mock",
        )
        refreshed_context = dict(session.context_json or {})
        refreshed_context.update(latest_context)
        refreshed_context.update(intent.extracted_entities)
        session.context_json = refreshed_context
        request.intent = intent.intent.value
        reported_weak_points = [
            point for point in (intent.extracted_entities.get("weakPoints") or []) if point in message
        ]
        facts: dict[str, Any] = {
            "studentProfile": student_snapshot,
            "reportedWeakPoints": reported_weak_points,
            "reportedSubject": intent.extracted_entities.get("subject") or context.get("subject") or "",
        }
        history = await self.memory.recent_messages(session)
        if history and history[-1].get("role") == "user" and history[-1].get("content") == message:
            history = history[:-1]
        registry = await self._register_tools(session, request.request_id, student)
        tool_calls: list[dict[str, Any]] = []
        tool_facts: dict[str, Any] = {}
        cards: list[dict[str, Any]] = []
        sources: list[dict[str, Any]] = []
        agent_fallback_used = False

        if pending_decision == "cancel":
            facts.update({"confirmationCancelled": True, "message": "已取消待执行的报名操作，没有修改任何订单。"})
        elif pending_decision == "confirm" and pending_write:
            name = str(pending_write.get("tool") or "")
            arguments = dict(pending_write.get("arguments") or {})
            try:
                async with self.db.begin_nested():
                    result = await asyncio.wait_for(
                        self._execute_controlled_tool(
                            registry, session, name, arguments, confirmed_write=True
                        ),
                        timeout=TOOL_TIMEOUT_SECONDS,
                    )
                safe_result = jsonable_encoder(result)
                tool_calls.append({"name": name, "arguments": arguments, "result": safe_result, "success": True})
                sources.extend(self._merge_tool_result(name, safe_result, facts))
                cards.extend(self._cards_for_tool(name, safe_result))
                refreshed_context = dict(session.context_json or {})
                refreshed_context.pop("pendingWrite", None)
                session.context_json = refreshed_context
            except Exception as exc:
                facts.update({"writeFailed": True, "message": "报名操作执行失败，请核对课程后重试。"})
                tool_calls.append({
                    "name": name,
                    "arguments": arguments,
                    "result": {"error": exc.__class__.__name__, "message": str(exc)[:200]},
                    "success": False,
                })
                logger.warning(
                    "AI confirmed write failed request_id=%s tool=%s error_type=%s",
                    request.request_id,
                    name,
                    exc.__class__.__name__,
                )
        elif not intent.missing_fields:
            try:
                if self.provider.configured and self.provider.provider.name != "mock":
                    tool_calls, tool_facts, cards, sources, agent_fallback_used = await self._run_agent_tools(
                        registry, session, intent, message, history, student_snapshot
                    )
                required_tool_intents = {
                    IntentType.COURSE_RECOMMENDATION,
                    IntentType.COURSE_SEARCH,
                    IntentType.PAPER_SEARCH,
                    IntentType.STUDY_PLAN_GENERATION,
                    IntentType.LEARNING_ANALYSIS,
                    IntentType.KNOWLEDGE_QA,
                    IntentType.LEARNING_REPORT,
                    IntentType.WRONG_QUESTION_ANALYSIS,
                    IntentType.ORDER_CREATION,
                    IntentType.MY_COURSES,
                    IntentType.MY_ORDERS,
                }
                successful_tool_names = {
                    str(call.get("name") or "")
                    for call in tool_calls
                    if call.get("success") is not False
                }
                required_resource_tool = RESOURCE_TOOL_BY_INTENT.get(intent.intent)
                needs_deterministic_execution = (
                    (not tool_calls and intent.intent in required_tool_intents)
                    or (
                        required_resource_tool is not None
                        and required_resource_tool not in successful_tool_names
                    )
                )
                if needs_deterministic_execution:
                    async with self.db.begin_nested():
                        fallback_calls, fallback_facts, fallback_cards, fallback_sources = await self._execute(
                            registry, session, intent, message
                        )
                    tool_calls.extend(fallback_calls)
                    tool_facts.update(fallback_facts)
                    cards.extend(fallback_cards)
                    sources.extend(fallback_sources)
                    agent_fallback_used = True
                facts.update(tool_facts)
            except Exception as exc:
                agent_fallback_used = True
                facts["degradedStages"] = ["agent_tools"]
                logger.warning(
                    "AI tool fallback request_id=%s intent=%s error_type=%s",
                    request.request_id,
                    intent.intent.value,
                    exc.__class__.__name__,
                )
        facts["agentFallbackUsed"] = agent_fallback_used
        fallback = _fallback_answer(intent.intent, facts, intent.clarification_question)
        # 工具可能返回 Decimal、日期等数据库类型；在写入 JSON 字段和交给模型前统一转换，
        # 避免真实学习记录较丰富时在 prepare 阶段因不可序列化而整轮回滚。
        prepared_payload: dict[str, Any] = jsonable_encoder({
            "intent": intent.intent.value,
            "confidence": intent.confidence,
            "missingFields": intent.missing_fields,
            "clarificationQuestion": intent.clarification_question,
            "toolCalls": tool_calls,
            "cards": cards,
            "sources": sources,
            "facts": facts,
            "fallbackAnswer": fallback,
        })
        tool_calls = prepared_payload["toolCalls"]
        cards = prepared_payload["cards"]
        sources = prepared_payload["sources"]
        facts = prepared_payload["facts"]
        request.status = "prepared"
        request.response_json = prepared_payload
        await self.db.flush()
        return PreparedChat(request, session, intent, tool_calls, cards, sources, facts, fallback, history)

    def _messages(self, prepared: PreparedChat, message: str) -> list[dict[str, Any]]:
        evidence = json.dumps({"facts": prepared.facts, "sources": prepared.sources}, ensure_ascii=False)
        return [
            {"role": "system", "content": SYSTEM_PROMPT},
            *prepared.history,
            {"role": "user", "content": message},
            {"role": "system", "content": f"本轮可用事实与资料：{evidence}。只引用其中存在的业务事实。"},
        ]

    async def _stream_provider_with_heartbeat(
        self,
        messages: list[dict[str, Any]],
        fallback_content: str,
    ) -> AsyncIterator[str | None]:
        iterator = self.provider.stream(
            messages,
            fallback_content=fallback_content,
            temperature=0.6,
            max_tokens=2200,
        ).__aiter__()
        while True:
            next_chunk = asyncio.create_task(anext(iterator))
            while not next_chunk.done():
                try:
                    await asyncio.wait_for(asyncio.shield(next_chunk), timeout=4.0)
                except TimeoutError:
                    yield None
                except StopAsyncIteration:
                    return
            try:
                yield next_chunk.result()
            except StopAsyncIteration:
                return

    async def _complete(self, prepared: PreparedChat, message: str) -> dict:
        started = perf_counter()
        force_resource_fallback = prepared.intent.intent in RESOURCE_TOOL_BY_INTENT and not prepared.cards
        if force_resource_fallback:
            answer = prepared.fallback_answer
            model = "deterministic-resource-fallback"
            fallback_used = True
            metadata: dict[str, Any] = {
                "model": model,
                "fallbackUsed": True,
            }
        else:
            try:
                result = await self.provider.complete(
                    self._messages(prepared, message),
                    fallback_content=prepared.fallback_answer,
                    temperature=0.6,
                    max_tokens=2200,
                )
                answer = result.content or prepared.fallback_answer
                model = result.model
                fallback_used = result.fallback_used or bool(prepared.facts.get("agentFallbackUsed"))
                metadata = {
                    "model": model,
                    "usage": result.usage,
                    "latencyMs": result.latency_ms,
                    "fallbackUsed": fallback_used,
                }
            except ProviderError as exc:
                answer = prepared.fallback_answer
                model = "deterministic-fallback"
                fallback_used = True
                metadata = {"model": model, "fallbackUsed": True, "errorCode": exc.code}
                logger.warning(
                    "AI final fallback request_id=%s error_code=%s",
                    prepared.request.request_id,
                    exc.code,
                )
        logger.info(
            "AI stage request_id=%s stage=final latency_ms=%s fallback=%s",
            prepared.request.request_id,
            int((perf_counter() - started) * 1000),
            fallback_used,
        )
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
        metadata["cards"] = prepared.cards
        metadata["sources"] = prepared.sources
        self.memory.add_message(
            prepared.session,
            "assistant",
            answer,
            prepared.intent.intent.value,
            client_message_id=prepared.request.client_message_id,
            tool_calls=prepared.tool_calls,
            model_metadata=metadata,
        )
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
        # 先发送轻量事件建立 SSE 数据流，避免意图判断或工具准备阶段触发客户端静默超时。
        yield "meta", {
            "sessionId": session_id or "",
            "requestId": client_message_id or "",
            "preparing": True,
        }
        saved_queue: asyncio.Queue[dict] = asyncio.Queue()
        prepare_task = asyncio.create_task(self.prepare(
            student_profile_id, message, session_id, client_message_id, requested_user_id, saved_queue
        ))
        while not prepare_task.done():
            try:
                saved = await asyncio.wait_for(saved_queue.get(), timeout=4.0)
                yield "message_saved", saved
            except TimeoutError:
                yield "status", {"stage": "preparing", "message": "正在分析学习情况并查询资料"}
        while not saved_queue.empty():
            yield "message_saved", saved_queue.get_nowait()
        prepared = await prepare_task
        if isinstance(prepared, dict):
            yield "meta", {
                "sessionId": prepared["sessionId"],
                "requestId": prepared["requestId"],
                "replayed": True,
                "preparing": False,
            }
            yield "delta", {"content": prepared["answer"]}
            yield "done", prepared
            return
        yield "meta", {
            "sessionId": prepared.session.id,
            "requestId": prepared.request.request_id,
            "fallbackUsed": False,
            "preparing": False,
        }
        yield "intent", {"intent": prepared.intent.intent.value, "confidence": prepared.intent.confidence,
                          "missingFields": prepared.intent.missing_fields, "clarificationQuestion": prepared.intent.clarification_question}
        for call in prepared.tool_calls:
            yield "tool_start", {"name": call["name"], "arguments": call["arguments"]}
            yield "tool_result", {"name": call["name"], "result": call["result"]}
        for source in prepared.sources:
            yield "source", {key: value for key, value in source.items() if key != "content"} | {"excerpt": source["content"][:180]}

        chunks: list[str] = []
        started = perf_counter()
        force_resource_fallback = prepared.intent.intent in RESOURCE_TOOL_BY_INTENT and not prepared.cards
        if force_resource_fallback:
            chunks.append(prepared.fallback_answer)
            yield "delta", {"content": prepared.fallback_answer}
            model = "deterministic-resource-fallback"
            fallback_used = True
        else:
            try:
                async for delta in self._stream_provider_with_heartbeat(
                    self._messages(prepared, message), prepared.fallback_answer
                ):
                    if delta is None:
                        yield "status", {"stage": "generating", "message": "正在组织个性化回答"}
                        continue
                    chunks.append(delta)
                    yield "delta", {"content": delta}
                model = self.provider.provider.model
                fallback_used = (
                    self.provider.provider.name == "mock"
                    or not self.provider.configured
                    or bool(prepared.facts.get("agentFallbackUsed"))
                )
            except ProviderError as exc:
                if chunks:
                    prepared.request.status = "failed"
                    prepared.request.error_code = exc.code
                    await self.db.commit()
                    yield "error", {"code": exc.code, "message": str(exc), "requestId": prepared.request.request_id}
                    return
                chunks.append(prepared.fallback_answer)
                yield "delta", {"content": prepared.fallback_answer}
                model = "deterministic-fallback"
                fallback_used = True
                logger.warning(
                    "AI final stream fallback request_id=%s error_code=%s",
                    prepared.request.request_id,
                    exc.code,
                )
        logger.info(
            "AI stage request_id=%s stage=final_stream latency_ms=%s fallback=%s",
            prepared.request.request_id,
            int((perf_counter() - started) * 1000),
            fallback_used,
        )
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
        self.memory.add_message(
            prepared.session,
            "assistant",
            answer,
            prepared.intent.intent.value,
            client_message_id=prepared.request.client_message_id,
            tool_calls=prepared.tool_calls,
            model_metadata={
                "model": model,
                "fallbackUsed": fallback_used,
                "cards": prepared.cards,
                "sources": prepared.sources,
            },
        )
        await self.memory.summarize_if_needed(prepared.session)
        prepared.request.status = "completed"
        prepared.request.response_json = response
        await self.db.commit()
        yield "done", response
