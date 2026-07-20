import uuid

import pytest
from pydantic import ValidationError

from server.database import SessionLocal
from server.schemas.dto import StudentCreate
from server.services.seed_service import seed_catalog


GRADES = ["一年级", "二年级", "三年级", "四年级", "五年级", "六年级"]
SUBJECTS = ["语文", "数学", "英语"]


def auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def register_parent(client) -> dict:
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"catalog_{suffix}",
        "phone": f"139{suffix}",
        "password": "secret123",
        "role": "parent",
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


def test_student_schema_supports_all_primary_grades_and_core_subjects():
    for grade in GRADES:
        for subject in SUBJECTS:
            payload = StudentCreate(
                name="测试学生",
                grade=grade,
                subject=subject,
                recent_score=80,
                weak_points=["专项训练"],
                learning_goal="提高成绩",
                weekly_study_minutes=180,
            )
            assert payload.grade == grade
            assert payload.subject == subject

    with pytest.raises(ValidationError):
        StudentCreate(
            name="测试学生", grade="初一", subject="科学", recent_score=80,
            weak_points=[], learning_goal="提高成绩", weekly_study_minutes=180,
        )


@pytest.mark.asyncio
async def test_catalog_is_complete_idempotent_and_preserves_legacy_order(client):
    parent = await register_parent(client)
    headers = auth_headers(parent["accessToken"])

    courses_response = await client.get("/api/courses", headers=headers)
    papers_response = await client.get("/api/papers", headers=headers)
    assert courses_response.status_code == 200
    assert papers_response.status_code == 200
    courses = courses_response.json()["data"]
    papers = papers_response.json()["data"]
    assert len(courses) == 54
    assert len(papers) == 108
    assert courses[0]["name"] == "五年级数学基础巩固课"
    assert courses[3]["name"] == "五年级英语基础巩固课"
    assert courses[6]["name"] == "六年级数学基础巩固课"
    assert courses[9]["name"] == "六年级英语基础巩固课"

    async with SessionLocal() as db:
        await seed_catalog(db)

    assert len((await client.get("/api/courses", headers=headers)).json()["data"]) == 54
    assert len((await client.get("/api/papers", headers=headers)).json()["data"]) == 108

    for grade, subject in (("一年级", "语文"), ("三年级", "英语"), ("六年级", "数学")):
        filtered_courses = (await client.get(
            "/api/courses", headers=headers, params={"grade": grade, "subject": subject}
        )).json()["data"]
        filtered_papers = (await client.get(
            "/api/papers", headers=headers, params={"grade": grade, "subject": subject}
        )).json()["data"]
        assert len(filtered_courses) == 3
        assert len(filtered_papers) == 6
        assert all(row["grade"] == grade and row["subject"] == subject for row in filtered_courses)
        assert all(row["grade"] == grade and row["subject"] == subject for row in filtered_papers)


@pytest.mark.asyncio
async def test_student_profile_can_move_across_grades_and_subjects(client):
    parent = await register_parent(client)
    headers = auth_headers(parent["accessToken"])
    created = await client.post("/api/students", headers=headers, json={
        "name": "小雨", "grade": "一年级", "subject": "语文", "recent_score": 86,
        "weak_points": ["拼音", "看图写话"], "learning_goal": "培养习惯", "weekly_study_minutes": 90,
    })
    assert created.status_code == 200, created.text
    student_id = created.json()["data"]["id"]
    assert created.json()["data"]["grade"] == "一年级"
    assert created.json()["data"]["subjects"][0]["subject"] == "语文"

    updated = await client.put(f"/api/students/{student_id}", headers=headers, json={
        "name": "小雨", "grade": "三年级", "subject": "英语", "recent_score": 78,
        "weak_points": ["词汇", "听力"], "learning_goal": "查漏补缺", "weekly_study_minutes": 180,
    })
    assert updated.status_code == 200, updated.text
    assert updated.json()["data"]["grade"] == "三年级"
    assert any(item["subject"] == "英语" for item in updated.json()["data"]["subjects"])

    recommendation = await client.post("/api/courses/recommend", headers=headers, json={
        "student_profile_id": student_id, "subject": "英语",
    })
    assert recommendation.status_code == 200, recommendation.text
    courses = recommendation.json()["data"]["recommendation"]["courses"]
    assert courses
    detail = await client.get(f"/api/courses/{courses[0]['id']}", headers=headers)
    assert detail.json()["data"]["grade"] == "三年级"
    assert detail.json()["data"]["subject"] == "英语"
