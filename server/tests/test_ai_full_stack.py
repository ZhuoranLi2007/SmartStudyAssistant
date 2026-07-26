import asyncio
import json
import uuid
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, PropertyMock, patch

import pytest
from sqlalchemy import func, select

from server.ai.intent import IntentType
from server.ai.intent.intent_classifier import IntentClassifier, classify_by_rules
from server.ai.providers import DeepSeekProvider, ProviderError, ProviderResult, ProviderToolCall
from server.ai.rag import RAGService
from server.database import SessionLocal
from server.models import CourseOrder, RagChunk, RagDocument


async def register_parent(client):
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"ai_{suffix}", "phone": f"139{suffix}", "password": "secret123", "role": "parent",
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


async def create_student(client, parent, weak_points=None):
    response = await client.put(
        f"/api/students/{parent['studentProfileId']}",
        headers={"Authorization": f"Bearer {parent['accessToken']}"},
        json={
        "name": "AI测试学生", "grade": "六年级", "subject": "数学", "recent_score": 82,
        "weak_points": ["应用题"] if weak_points is None else weak_points,
        "learning_goal": "提高成绩", "weekly_study_minutes": 210,
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


@pytest.mark.parametrize(("message", "point"), [
    ("应用题比较弱", "应用题"),
    ("百分数不擅长", "百分数"),
    ("阅读总出错", "阅读"),
])
def test_weakness_statement_uses_deterministic_learning_analysis(message, point):
    result = classify_by_rules(message, {
        "studentId": 1, "grade": "六年级", "subject": "数学", "score": 75,
        "weakPoints": ["百分数"], "learningGoal": "提高成绩",
    })
    assert result.intent == IntentType.LEARNING_ANALYSIS
    assert result.confidence >= 0.9
    assert result.extracted_entities["weakPoints"] == [point]


@pytest.mark.parametrize(
    ("message", "expected_intent"),
    [
        ("孩子六年级数学82分，应用题较弱，请推荐课程", IntentType.COURSE_RECOMMENDATION),
        ("孩子六年级数学82分，应用题较弱，请推荐试卷", IntentType.PAPER_SEARCH),
    ],
)
def test_explicit_resource_request_takes_priority_over_weakness_statement(
    message,
    expected_intent,
):
    result = classify_by_rules(message, {
        "studentId": 1, "grade": "六年级", "subject": "数学", "score": 82,
        "weakPoints": ["百分数"], "learningGoal": "提高成绩",
    })
    assert result.intent == expected_intent


@pytest.mark.asyncio
async def test_malformed_model_intent_response_falls_back_to_rules():
    provider = AsyncMock()
    provider.complete = AsyncMock(return_value=ProviderResult(content="[]", model="invalid-json-shape"))
    result = await IntentClassifier(provider).classify("请给我一些学习建议", {"studentId": 1})
    assert result.intent == IntentType.GENERAL_CHAT


@pytest.mark.asyncio
async def test_deepseek_provider_parses_tool_calls_and_rejects_invalid_arguments():
    provider = DeepSeekProvider("test-key", "https://api.deepseek.com", "deepseek-v4-flash", 5, 0.3)
    create = AsyncMock(return_value=SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(
            content="",
            tool_calls=[SimpleNamespace(
                id="call_1",
                function=SimpleNamespace(name="student_profile_tool", arguments='{"subject":"数学"}'),
            )],
        ))],
        model="deepseek-v4-flash",
        usage=None,
    ))
    provider._client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create)))
    result = await provider.complete(
        [{"role": "user", "content": "分析数学学习情况"}],
        tools=[{"type": "function", "function": {"name": "student_profile_tool", "parameters": {"type": "object"}}}],
    )
    assert result.tool_calls[0].name == "student_profile_tool"
    assert result.tool_calls[0].arguments == {"subject": "数学"}
    assert create.await_args.kwargs["tool_choice"] == "auto"

    create.return_value = SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(
            content="",
            tool_calls=[SimpleNamespace(
                id="call_2",
                function=SimpleNamespace(name="student_profile_tool", arguments="[]"),
            )],
        ))],
        model="deepseek-v4-flash",
        usage=None,
    )
    with pytest.raises(ProviderError) as error:
        await provider.complete(
            [{"role": "user", "content": "分析"}],
            tools=[{"type": "function", "function": {"name": "student_profile_tool", "parameters": {"type": "object"}}}],
        )
    assert error.value.code == "AI_INVALID_TOOL_ARGUMENTS"


@pytest.mark.asyncio
async def test_rag_filters_grade_subject_and_updates_existing_metadata(client):
    async with SessionLocal() as db:
        service = RAGService(db)
        content = "应用题训练：先分析数量关系，再分步列式。"
        document_id, created = await service._upsert_document(
            "course", "filter-six", "六年级应用题", content,
            {"grade": "六年级", "subject": "数学", "knowledgePoints": ["应用题"]},
        )
        assert created is True
        await service._upsert_document(
            "course", "filter-five", "五年级应用题", content + "五年级",
            {"grade": "五年级", "subject": "数学", "knowledgePoints": ["应用题"]},
        )
        same_id, created = await service._upsert_document(
            "course", "filter-six", "六年级应用题", content,
            {"grade": "六年级", "subject": "数学", "level": "中等提升型", "knowledgePoints": ["应用题"]},
        )
        assert same_id == document_id
        assert created is False
        await db.commit()

        rows = await service.search(
            "应用题数量关系",
            grade="六年级",
            subject="数学",
            source_types=["course"],
            top_k=6,
        )
        assert rows
        assert {row["title"] for row in rows} == {"六年级应用题"}
        chunk = await db.scalar(select(RagChunk).where(RagChunk.document_id == document_id))
        document = await db.get(RagDocument, document_id)
        assert document.metadata_json["level"] == "中等提升型"
        assert chunk.metadata_json["level"] == "中等提升型"


@pytest.mark.asyncio
async def test_deepseek_agent_uses_tools_and_deepens_repeated_weakness_answer(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent, weak_points=["百分数"])

    def intent_result() -> ProviderResult:
        return ProviderResult(
            content='{"intent":"LEARNING_ANALYSIS","confidence":0.96}',
            model="deepseek-v4-flash",
        )

    def tool_result(prefix: str) -> ProviderResult:
        return ProviderResult(
            content="",
            model="deepseek-v4-flash",
            tool_calls=[
                ProviderToolCall(f"{prefix}_rag", "knowledge_search_tool", {
                    "query": "六年级数学应用题解题方法",
                    "subject": "数学",
                    "sourceTypes": ["knowledge"],
                    "topK": 4,
                }),
                ProviderToolCall(f"{prefix}_rag_overlap", "knowledge_search_tool", {
                    "query": "六年级数学百分数应用题解题技巧",
                    "subject": "数学",
                    "sourceTypes": ["knowledge"],
                    "topK": 5,
                }),
            ],
        )

    side_effects = [
        intent_result(), tool_result("one"),
        ProviderResult(content="本轮反馈是应用题较弱；档案记录的薄弱点是百分数。先练习提取条件和数量关系。", model="deepseek-v4-flash"),
        intent_result(), tool_result("two"),
        ProviderResult(content="继续深入应用题：今天把错误分成审题、建模和计算三类，再各复练一道；档案仍记录百分数。", model="deepseek-v4-flash"),
    ]
    marker = SimpleNamespace(name="deepseek", model="deepseek-v4-flash")
    provider_complete = AsyncMock(side_effect=side_effects)
    with (
        patch("server.ai.providers.provider_router.ProviderRouter.configured", new_callable=PropertyMock, return_value=True),
        patch("server.ai.providers.provider_router.ProviderRouter.provider", new_callable=PropertyMock, return_value=marker),
        patch("server.ai.providers.provider_router.ProviderRouter.complete", new=provider_complete),
    ):
        first = await client.post("/api/ai/chat", headers=auth, json={
            "studentProfileId": student["id"],
            "clientMessageId": str(uuid.uuid4()),
            "message": "应用题比较弱",
        })
        assert first.status_code == 200, first.text
        first_data = first.json()["data"]
        second = await client.post("/api/ai/chat", headers=auth, json={
            "sessionId": first_data["sessionId"],
            "studentProfileId": student["id"],
            "clientMessageId": str(uuid.uuid4()),
            "message": "应用题比较弱",
        })
        assert second.status_code == 200, second.text

    second_data = second.json()["data"]
    assert first_data["answer"] != second_data["answer"]
    assert "应用题" in first_data["answer"] and "百分数" in first_data["answer"]
    assert "应用题" in second_data["answer"] and "百分数" in second_data["answer"]
    assert [item["name"] for item in first_data["toolCalls"]] == ["knowledge_search_tool"]
    first_agent_tools = provider_complete.await_args_list[1].kwargs["tools"]
    assert {item["function"]["name"] for item in first_agent_tools} == {"knowledge_search_tool"}
    profile = await client.get(f"/api/students/{student['id']}", headers=auth)
    assert profile.json()["data"]["subjects"][0]["weakPoints"] == ["百分数"]


@pytest.mark.asyncio
async def test_sse_emits_preparing_heartbeat_during_slow_agent_stage(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)

    async def slow_prepare(*_args, **_kwargs):
        await asyncio.sleep(4.1)
        answer = "准备完成"
        return {
            "sessionId": "heartbeat-session",
            "intent": "GENERAL_CHAT",
            "confidence": 1.0,
            "answer": answer,
            "assistantMessage": answer,
            "missingFields": [],
            "clarificationQuestion": None,
            "toolCalls": [],
            "cards": [],
            "sources": [],
            "fallbackUsed": False,
            "requestId": "heartbeat-request",
        }

    with patch("server.ai.orchestrator.AIOrchestrator.prepare", new=slow_prepare):
        response = await client.post("/api/ai/chat/stream", headers=auth, json={
            "studentProfileId": student["id"],
            "clientMessageId": str(uuid.uuid4()),
            "message": "请分析学习情况",
        })
    assert response.status_code == 200
    assert response.text.index("event: meta") < response.text.index("event: status")
    assert response.text.index("event: status") < response.text.index("event: done")


@pytest.mark.asyncio
async def test_weakness_statement_streams_answer_without_mutating_profile(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent, weak_points=["百分数"])
    client_message_id = str(uuid.uuid4())

    stream = await client.post("/api/ai/chat/stream", headers=auth, json={
        "studentProfileId": student["id"],
        "clientMessageId": client_message_id,
        "message": "应用题比较弱",
    })
    assert stream.status_code == 200, stream.text
    assert "event: error" not in stream.text
    assert stream.text.index("event: meta") < stream.text.index("event: intent")
    assert stream.text.index("event: intent") < stream.text.index("event: delta")
    assert stream.text.index("event: delta") < stream.text.index("event: done")
    done_text = stream.text.split("event: done\ndata: ", 1)[1].split("\n\n", 1)[0]
    done = json.loads(done_text)
    assert done["intent"] == "LEARNING_ANALYSIS"
    assert "应用题" in done["answer"]
    assert "百分数" in done["answer"]
    assert "不会自动修改学生档案" in done["answer"]

    replay = await client.post("/api/ai/chat", headers=auth, json={
        "sessionId": done["sessionId"],
        "studentProfileId": student["id"],
        "clientMessageId": client_message_id,
        "message": "应用题比较弱",
    })
    assert replay.status_code == 200, replay.text
    assert replay.json()["data"]["requestId"] == done["requestId"]
    assert replay.json()["data"]["answer"] == done["answer"]

    profile = await client.get(f"/api/students/{student['id']}", headers=auth)
    assert profile.status_code == 200, profile.text
    assert profile.json()["data"]["subjects"][0]["weakPoints"] == ["百分数"]


@pytest.mark.asyncio
async def test_learning_analysis_degrades_when_learning_tools_and_rag_fail(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent, weak_points=["百分数"])

    with (
        patch("server.ai.orchestrator.LearningReportTool.execute", new=AsyncMock(side_effect=RuntimeError("tool unavailable"))),
        patch("server.tools.knowledge_search_tool.RAGService.search", new=AsyncMock(side_effect=RuntimeError("rag unavailable"))),
    ):
        response = await client.post("/api/ai/chat", headers=auth, json={
            "studentProfileId": student["id"],
            "clientMessageId": str(uuid.uuid4()),
            "message": "请分析当前学习情况",
        })

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["intent"] == "LEARNING_ANALYSIS"
    assert data["answer"]
    assert data["cards"] == []


@pytest.mark.asyncio
async def test_learning_analysis_serializes_decimal_tool_facts(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent, weak_points=["百分数"])

    report = {
        "learningReport": {
            "aiSuggestion": "继续巩固",
            "recommendedCourse": {"id": 1, "price": Decimal("99.00")},
        },
    }
    with patch(
        "server.ai.orchestrator.LearningReportTool.execute",
        new=AsyncMock(return_value=report),
    ):
        response = await client.post("/api/ai/chat", headers=auth, json={
            "studentProfileId": student["id"],
            "clientMessageId": str(uuid.uuid4()),
            "message": "请分析当前学习情况",
        })

    assert response.status_code == 200, response.text
    assert response.json()["data"]["intent"] == "LEARNING_ANALYSIS"
    assert response.json()["data"]["answer"]


@pytest.mark.asyncio
async def test_health_rag_and_structured_ai_response(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)

    health = await client.get("/api/ai/health")
    assert health.status_code == 200
    assert health.json()["data"]["activeProvider"] == "mock"

    rebuild = await client.post("/api/ai/rag/rebuild", headers=auth)
    assert rebuild.status_code == 200, rebuild.text
    assert rebuild.json()["data"]["documents"] >= 38

    response = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"],
        "clientMessageId": str(uuid.uuid4()),
        "message": "孩子六年级数学82分，应用题较弱，请推荐课程",
    })
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["intent"] == "COURSE_RECOMMENDATION"
    assert data["fallbackUsed"] is True
    assert data["cards"]
    assert data["requestId"]
    assert all(card["id"] > 0 for card in data["cards"])
    course_cards = [card for card in data["cards"] if card["type"] == "COURSE"]
    assert course_cards
    assert course_cards[0]["grade"] == "六年级"
    assert course_cards[0]["subject"] == "数学"
    assert course_cards[0]["lessonCount"] > 0
    assert course_cards[0]["recommendationReason"]


@pytest.mark.asyncio
async def test_home_aggregation_and_ai_route_are_registered(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)

    home = await client.get(
        "/api/home",
        headers=auth,
        params={"student_profile_id": student["id"]},
    )
    assert home.status_code == 200, home.text
    data = home.json()["data"]
    assert data["overview"]["studentBound"] is True
    assert data["overview"]["studentName"]
    assert len(data["banners"]) == 3
    assert len(data["popularCourses"]) == 4
    assert len(data["latestCourses"]) == 4
    assert len(data["recommendedPapers"]) == 4

    ai = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"],
        "clientMessageId": str(uuid.uuid4()),
        "message": "请帮我分析当前学习情况",
    })
    assert ai.status_code == 200, ai.text


@pytest.mark.asyncio
async def test_stale_student_profile_id_returns_guidance_instead_of_404(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}

    home = await client.get("/api/home", headers=auth, params={"student_profile_id": 999999})
    assert home.status_code == 200, home.text
    assert home.json()["data"]["studentProfileId"] == 0
    assert home.json()["data"]["overview"]["studentBound"] is False

    chat = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": 999999,
        "clientMessageId": str(uuid.uuid4()),
        "message": "请帮我推荐课程",
    })
    assert chat.status_code == 200, chat.text
    data = chat.json()["data"]
    assert data["missingFields"] == ["studentProfile"]
    assert data["cards"] == []


@pytest.mark.asyncio
async def test_user_without_student_can_ask_general_question(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}

    response = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": 0,
        "clientMessageId": str(uuid.uuid4()),
        "message": "小学阶段应该怎样培养每天阅读的习惯？",
    })
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["intent"] in {"GENERAL_CHAT", "KNOWLEDGE_QA"}
    assert data["answer"]
    assert data["missingFields"] == []
    assert data["sessionId"] == ""


@pytest.mark.asyncio
async def test_sse_order_and_study_plan_card_details(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)

    before = await client.get(
        "/api/study-plans",
        headers=auth,
        params={"student_profile_id": student["id"]},
    )
    assert before.status_code == 200, before.text

    client_message_id = str(uuid.uuid4())
    stream = await client.post("/api/ai/chat/stream", headers=auth, json={
        "studentProfileId": student["id"],
        "clientMessageId": client_message_id,
        "message": "请根据学生档案生成一周学习计划",
    })
    assert stream.status_code == 200, stream.text
    body = stream.text
    assert body.index("event: meta") < body.index("event: intent")
    assert body.index("event: intent") < body.index("event: tool_start")
    assert body.index("event: tool_start") < body.index("event: delta")
    assert body.index("event: delta") < body.index("event: done")
    done_text = body.split("event: done\ndata: ", 1)[1].split("\n\n", 1)[0]
    done = json.loads(done_text)
    plan_cards = [card for card in done["cards"] if card["type"] == "STUDY_PLAN"]
    assert len(plan_cards) == 1
    assert len(plan_cards[0]["tasks"]) == 7
    assert plan_cards[0]["tasks"][0]["durationMinutes"] > 0
    assert plan_cards[0]["id"] == 0
    assert all(task["id"] < 0 for task in plan_cards[0]["tasks"])
    assert all(task["courseId"] is None and task["paperId"] is None for task in plan_cards[0]["tasks"])

    replay = await client.post("/api/ai/chat", headers=auth, json={
        "sessionId": done["sessionId"],
        "studentProfileId": student["id"],
        "clientMessageId": client_message_id,
        "message": "请根据学生档案生成一周学习计划",
    })
    assert replay.status_code == 200, replay.text
    assert replay.json()["data"]["requestId"] == done["requestId"]
    assert replay.json()["data"]["cards"] == done["cards"]

    after = await client.get(
        "/api/study-plans",
        headers=auth,
        params={"student_profile_id": student["id"]},
    )
    assert after.status_code == 200, after.text
    assert after.json()["data"] == before.json()["data"]


@pytest.mark.asyncio
async def test_study_plan_preview_without_weak_points(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent, weak_points=[])

    response = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"],
        "clientMessageId": str(uuid.uuid4()),
        "message": "请生成一周学习计划",
    })
    assert response.status_code == 200, response.text
    plan_cards = [card for card in response.json()["data"]["cards"] if card["type"] == "STUDY_PLAN"]
    assert len(plan_cards) == 1
    assert len(plan_cards[0]["tasks"]) == 7
    assert plan_cards[0]["tasks"][0]["knowledgePoint"] == "数学基础知识"


@pytest.mark.asyncio
async def test_order_confirmation_and_idempotent_retry(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)

    not_confirmed = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"], "message": "我想看看课程1",
    })
    assert not_confirmed.status_code == 200
    assert not_confirmed.json()["data"]["intent"] != "ORDER_CREATION"

    proposal_message_id = str(uuid.uuid4())
    first = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"], "clientMessageId": proposal_message_id,
        "message": "确认报名课程1，创建订单",
    })
    assert first.status_code == 200, first.text
    first_data = first.json()["data"]
    assert first_data["intent"] == "ORDER_CREATION"
    assert "再次明确回复" in first_data["answer"]
    assert not [item for item in first_data["cards"] if item["type"] == "ORDER"]

    async with SessionLocal() as db:
        assert await db.scalar(select(func.count(CourseOrder.id))) == 0

    client_message_id = str(uuid.uuid4())
    confirmed = await client.post("/api/ai/chat", headers=auth, json={
        "sessionId": first_data["sessionId"], "studentProfileId": student["id"],
        "clientMessageId": client_message_id, "message": "确认报名",
    })
    assert confirmed.status_code == 200, confirmed.text
    confirmed_data = confirmed.json()["data"]
    order_cards = [item for item in confirmed_data["cards"] if item["type"] == "ORDER"]
    assert len(order_cards) == 1

    replay = await client.post("/api/ai/chat", headers=auth, json={
        "sessionId": confirmed_data["sessionId"], "studentProfileId": student["id"],
        "clientMessageId": client_message_id, "message": "确认报名",
    })
    assert replay.status_code == 200
    assert replay.json()["data"]["requestId"] == confirmed_data["requestId"]

    async with SessionLocal() as db:
        assert await db.scalar(select(func.count(CourseOrder.id))) == 1


@pytest.mark.asyncio
async def test_paper_attempt_creates_real_learning_report(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)
    question_response = await client.get("/api/papers/1/questions", headers=auth)
    assert question_response.status_code == 200
    questions = question_response.json()["data"]["questions"]
    assert len(questions) == 5

    attempt = await client.post("/api/papers/1/attempts", headers=auth, json={
        "studentProfileId": student["id"],
        "answers": [{"questionId": item["id"], "selectedIndex": 0} for item in questions],
    })
    assert attempt.status_code == 200, attempt.text
    assert attempt.json()["data"]["questionCount"] == 5

    report = await client.get(f"/api/students/{student['id']}/learning-report", headers=auth)
    assert report.status_code == 200
    assert report.json()["data"]["completedPaperCount"] == 1


@pytest.mark.asyncio
async def test_general_chat_refreshes_latest_student_profile_in_same_session(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent)

    first = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"], "clientMessageId": str(uuid.uuid4()),
        "message": "请结合我的具体情况给一些学习建议",
    })
    assert first.status_code == 200, first.text
    first_data = first.json()["data"]
    assert "AI测试学生" in first_data["answer"]
    assert "82" in first_data["answer"]
    assert "应用题" in first_data["answer"]

    updated = await client.put(f"/api/students/{student['id']}", headers=auth, json={
        "name": "AI测试学生", "grade": "六年级", "subject": "数学", "recent_score": 91,
        "weak_points": ["百分数"], "learning_goal": "冲刺优秀", "weekly_study_minutes": 260,
    })
    assert updated.status_code == 200, updated.text

    second = await client.post("/api/ai/chat", headers=auth, json={
        "sessionId": first_data["sessionId"], "studentProfileId": student["id"],
        "clientMessageId": str(uuid.uuid4()), "message": "现在再结合我的具体情况给建议",
    })
    assert second.status_code == 200, second.text
    answer = second.json()["data"]["answer"]
    assert "91" in answer
    assert "百分数" in answer
