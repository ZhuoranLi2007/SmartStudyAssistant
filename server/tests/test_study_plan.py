import uuid

import pytest


async def register(client, role: str):
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"plan_{role}_{suffix}",
        "phone": f"137{suffix}",
        "password": "secret123",
        "role": role,
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


def headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_study_plan_roles_fields_and_recommended_papers(client):
    parent = await register(client, "parent")
    parent_headers = headers(parent["accessToken"])
    created = await client.post("/api/students", headers=parent_headers, json={
        "name": "计划学生", "grade": "六年级", "subject": "数学", "recent_score": 76,
        "weak_points": ["应用题", "百分数"], "learning_goal": "提高成绩", "weekly_study_minutes": 200,
    })
    assert created.status_code == 200, created.text
    student = created.json()["data"]

    recommended = await client.get("/api/study-plans/recommended-papers", headers=parent_headers, params={
        "student_profile_id": student["id"], "limit": 3,
    })
    assert recommended.status_code == 200, recommended.text
    papers = recommended.json()["data"]
    assert len(papers) == 3
    assert papers[0]["grade"] == "六年级"
    assert papers[0]["subject"] == "数学"
    assert papers[0]["recommendReason"]

    added = await client.post("/api/study-plans", headers=parent_headers, json={
        "student_profile_id": student["id"], "task_type": "试卷", "target_id": papers[0]["id"],
    })
    assert added.status_code == 200, added.text
    task = added.json()["data"]
    assert task["targetId"] == papers[0]["id"]
    assert task["scheduledDate"]
    assert task["durationMinutes"] == 40
    assert task["knowledgePoint"]

    duplicate = await client.post("/api/study-plans", headers=parent_headers, json={
        "student_profile_id": student["id"], "task_type": "试卷", "target_id": papers[0]["id"],
    })
    assert duplicate.status_code == 409

    student_user = await register(client, "student")
    student_headers = headers(student_user["accessToken"])
    bound = await client.post("/api/families/bind-student", headers=student_headers, json={
        "bind_code": student["bindCode"],
    })
    assert bound.status_code == 200, bound.text

    forbidden_add = await client.post("/api/study-plans", headers=student_headers, json={
        "student_profile_id": student["id"], "task_type": "试卷", "target_id": papers[1]["id"],
    })
    assert forbidden_add.status_code == 403

    parent_status = await client.put(f"/api/study-plans/{task['id']}/status", headers=parent_headers, json={
        "status": "学习中",
    })
    assert parent_status.status_code == 403

    student_status = await client.put(f"/api/study-plans/{task['id']}/status", headers=student_headers, json={
        "status": "已完成",
    })
    assert student_status.status_code == 200, student_status.text
    assert student_status.json()["data"]["status"] == "已完成"

    student_delete = await client.delete(f"/api/study-plans/{task['id']}", headers=student_headers)
    assert student_delete.status_code == 403
    parent_delete = await client.delete(f"/api/study-plans/{task['id']}", headers=parent_headers)
    assert parent_delete.status_code == 200


@pytest.mark.asyncio
async def test_study_plan_family_isolation(client):
    first_parent = await register(client, "parent")
    created = await client.post("/api/students", headers=headers(first_parent["accessToken"]), json={
        "name": "隔离学生", "grade": "五年级", "subject": "英语", "recent_score": 80,
        "weak_points": ["阅读"], "learning_goal": "提高成绩", "weekly_study_minutes": 180,
    })
    student = created.json()["data"]
    second_parent = await register(client, "parent")
    forbidden = await client.get("/api/study-plans/recommended-papers", headers=headers(second_parent["accessToken"]), params={
        "student_profile_id": student["id"],
    })
    assert forbidden.status_code == 403
