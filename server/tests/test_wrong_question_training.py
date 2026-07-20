import uuid

import pytest


async def register(client, role: str):
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"wrong_{role}_{suffix}",
        "phone": f"136{suffix}",
        "password": "secret123",
        "role": role,
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_wrong_question_plan_retest_and_mastery(client):
    parent = await register(client, "parent")
    parent_headers = auth(parent["accessToken"])
    created = await client.post("/api/students", headers=parent_headers, json={
        "name": "错题训练学生", "grade": "六年级", "subject": "数学", "recent_score": 75,
        "weak_points": ["分数"], "learning_goal": "查漏补缺", "weekly_study_minutes": 180,
    })
    assert created.status_code == 200, created.text
    student = created.json()["data"]

    questions_response = await client.get("/api/papers/1/questions", headers=parent_headers)
    questions = questions_response.json()["data"]["questions"]
    attempt = await client.post("/api/papers/1/attempts", headers=parent_headers, json={
        "studentProfileId": student["id"],
        "answers": [{"questionId": item["id"], "selectedIndex": 0} for item in questions],
    })
    assert attempt.status_code == 200, attempt.text

    recommended = await client.get("/api/study-plans/recommended-wrong-questions", headers=parent_headers, params={
        "student_profile_id": student["id"], "limit": 4,
    })
    assert recommended.status_code == 200, recommended.text
    wrong_items = recommended.json()["data"]
    assert wrong_items
    wrong = wrong_items[0]
    assert wrong["wrongCount"] >= 1

    task_response = await client.post("/api/study-plans", headers=parent_headers, json={
        "student_profile_id": student["id"], "task_type": "错题", "target_id": wrong["id"],
    })
    assert task_response.status_code == 200, task_response.text
    task = task_response.json()["data"]
    assert task["taskType"] == "错题"
    assert task["durationMinutes"] == 15

    duplicate = await client.post("/api/study-plans", headers=parent_headers, json={
        "student_profile_id": student["id"], "task_type": "错题", "target_id": wrong["id"],
    })
    assert duplicate.status_code == 409

    student_user = await register(client, "student")
    student_headers = auth(student_user["accessToken"])
    bound = await client.post("/api/families/bind-student", headers=student_headers, json={
        "bind_code": student["bindCode"],
    })
    assert bound.status_code == 200, bound.text

    training = await client.get(
        f"/api/students/{student['id']}/wrong-questions/{wrong['id']}/training", headers=student_headers
    )
    assert training.status_code == 200, training.text
    training_data = training.json()["data"]
    assert training_data["options"]
    assert "correctIndex" not in training_data
    assert "explanation" not in training_data

    incorrect_index = 0 if training_data["options"][0] != "50" else 1
    wrong_submit = await client.post(
        f"/api/students/{student['id']}/wrong-questions/{wrong['id']}/training/submit",
        headers=student_headers, json={"selectedIndex": incorrect_index},
    )
    assert wrong_submit.status_code == 200, wrong_submit.text
    wrong_result = wrong_submit.json()["data"]
    if wrong_result["correct"]:
        incorrect_index = (wrong_result["correctIndex"] + 1) % len(training_data["options"])
        wrong_submit = await client.post(
            f"/api/students/{student['id']}/wrong-questions/{wrong['id']}/training/submit",
            headers=student_headers, json={"selectedIndex": incorrect_index},
        )
        wrong_result = wrong_submit.json()["data"]
    assert wrong_result["correct"] is False
    assert wrong_result["mastered"] is False

    correct_submit = await client.post(
        f"/api/students/{student['id']}/wrong-questions/{wrong['id']}/training/submit",
        headers=student_headers, json={"selectedIndex": wrong_result["correctIndex"]},
    )
    assert correct_submit.status_code == 200, correct_submit.text
    assert correct_submit.json()["data"]["mastered"] is True

    tasks = await client.get("/api/study-plans", headers=student_headers, params={
        "student_profile_id": student["id"],
    })
    matching = [item for item in tasks.json()["data"] if item["id"] == task["id"]]
    assert matching[0]["status"] == "已完成"

    after = await client.get("/api/study-plans/recommended-wrong-questions", headers=parent_headers, params={
        "student_profile_id": student["id"],
    })
    assert all(item["id"] != wrong["id"] for item in after.json()["data"])
