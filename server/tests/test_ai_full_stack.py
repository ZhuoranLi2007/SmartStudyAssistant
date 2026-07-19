import uuid

import pytest


async def register_parent(client):
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"ai_{suffix}", "phone": f"139{suffix}", "password": "secret123", "role": "parent",
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


async def create_student(client, token):
    response = await client.post("/api/students", headers={"Authorization": f"Bearer {token}"}, json={
        "name": "AI测试学生", "grade": "六年级", "subject": "数学", "recent_score": 82,
        "weak_points": ["应用题"], "learning_goal": "提高成绩", "weekly_study_minutes": 210,
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


@pytest.mark.asyncio
async def test_health_rag_and_structured_ai_response(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent["accessToken"])

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


@pytest.mark.asyncio
async def test_home_aggregation_and_ai_route_are_registered(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent["accessToken"])

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
async def test_order_confirmation_and_idempotent_retry(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent["accessToken"])

    not_confirmed = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"], "message": "我想看看课程1",
    })
    assert not_confirmed.status_code == 200
    assert not_confirmed.json()["data"]["intent"] != "ORDER_CREATION"

    client_message_id = str(uuid.uuid4())
    first = await client.post("/api/ai/chat", headers=auth, json={
        "studentProfileId": student["id"], "clientMessageId": client_message_id,
        "message": "确认报名课程1，创建订单",
    })
    assert first.status_code == 200, first.text
    first_data = first.json()["data"]
    assert first_data["intent"] == "ORDER_CREATION"
    order_cards = [item for item in first_data["cards"] if item["type"] == "ORDER"]
    assert len(order_cards) == 1

    replay = await client.post("/api/ai/chat", headers=auth, json={
        "sessionId": first_data["sessionId"], "studentProfileId": student["id"],
        "clientMessageId": client_message_id, "message": "确认报名课程1，创建订单",
    })
    assert replay.status_code == 200
    assert replay.json()["data"]["requestId"] == first_data["requestId"]

    orders = await client.get("/api/orders", headers=auth)
    assert len(orders.json()["data"]) == 1


@pytest.mark.asyncio
async def test_paper_attempt_creates_real_learning_report(client):
    parent = await register_parent(client)
    auth = {"Authorization": f"Bearer {parent['accessToken']}"}
    student = await create_student(client, parent["accessToken"])
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
