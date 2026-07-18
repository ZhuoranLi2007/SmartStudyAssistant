import uuid

import pytest


async def register(client, role="parent"):
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"{role}_{suffix}", "phone": f"138{suffix[:8]}", "password": "secret123", "role": role,
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


def headers(token):
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_parent_student_recommendation_and_chat(client):
    parent = await register(client)
    auth = headers(parent["accessToken"])
    student_response = await client.post("/api/students", headers=auth, json={
        "name": "小明", "grade": "六年级", "subject": "数学", "recent_score": 75,
        "weak_points": ["应用题", "百分数"], "learning_goal": "提高成绩", "weekly_study_minutes": 180,
    })
    assert student_response.status_code == 200, student_response.text
    student = student_response.json()["data"]

    recommendation = await client.post("/api/courses/recommend", headers=auth, json={"student_profile_id": student["id"]})
    assert recommendation.status_code == 200
    assert recommendation.json()["data"]["recommendation"]["level"] == "中等提升型"

    chat = await client.post("/api/chat", headers=auth, json={
        "student_profile_id": student["id"], "message": "孩子六年级数学75分，应该报什么课？",
    })
    assert chat.status_code == 200, chat.text
    result = chat.json()["data"]
    assert result["intent"] == "COURSE_RECOMMENDATION"
    assert result["toolCalls"][0]["name"] == "CourseRecommendationTool"
    assert "中等提升型" in result["assistantMessage"]


@pytest.mark.asyncio
async def test_family_isolation_and_student_binding(client):
    first_parent = await register(client)
    first_headers = headers(first_parent["accessToken"])
    student_response = await client.post("/api/students", headers=first_headers, json={
        "name": "小华", "grade": "五年级", "subject": "英语", "recent_score": 88,
        "weak_points": ["阅读"], "learning_goal": "拓展学习", "weekly_study_minutes": 240,
    })
    student = student_response.json()["data"]

    second_parent = await register(client)
    forbidden = await client.get(f"/api/students/{student['id']}", headers=headers(second_parent["accessToken"]))
    assert forbidden.status_code == 403

    student_user = await register(client, "student")
    bound = await client.post("/api/families/bind-student", headers=headers(student_user["accessToken"]), json={
        "bind_code": student["bindCode"],
    })
    assert bound.status_code == 200, bound.text
    rebound = await client.post("/api/families/bind-student", headers=headers(student_user["accessToken"]), json={
        "bind_code": student["bindCode"],
    })
    assert rebound.status_code == 409
