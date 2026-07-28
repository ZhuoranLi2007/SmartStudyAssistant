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
async def test_demo_catalog_is_complete_idempotent_and_subject_scoped(client):
    parent = await register_parent(client)
    headers = auth_headers(parent["accessToken"])

    courses_response = await client.get("/api/courses", headers=headers)
    papers_response = await client.get("/api/papers", headers=headers)
    assert courses_response.status_code == 200
    assert papers_response.status_code == 200
    courses = courses_response.json()["data"]
    papers = papers_response.json()["data"]
    assert len(courses) == 15
    assert len(papers) == 15
    assert courses[0]["name"] == "分数基础巩固课程"
    assert courses[5]["name"] == "分数中等提升课程"
    assert courses[10]["name"] == "分数拔高拓展课程"
    assert all(row["grade"] == "五年级" and row["subject"] == "数学" for row in courses)
    assert all(row["grade"] == "五年级" and row["subject"] == "数学" for row in papers)

    async with SessionLocal() as db:
        await seed_catalog(db)

    assert len((await client.get("/api/courses", headers=headers)).json()["data"]) == 15
    assert len((await client.get("/api/papers", headers=headers)).json()["data"]) == 15

    for grade, subject, expected in (("五年级", "数学", 15), ("三年级", "英语", 0), ("六年级", "数学", 0)):
        filtered_courses = (await client.get(
            "/api/courses", headers=headers, params={"grade": grade, "subject": subject}
        )).json()["data"]
        filtered_papers = (await client.get(
            "/api/papers", headers=headers, params={"grade": grade, "subject": subject}
        )).json()["data"]
        assert len(filtered_courses) == expected
        assert len(filtered_papers) == expected
        assert all(row["grade"] == grade and row["subject"] == subject for row in filtered_courses)
        assert all(row["grade"] == grade and row["subject"] == subject for row in filtered_papers)


@pytest.mark.asyncio
async def test_student_profile_can_update_across_grades_and_subjects(client):
    parent = await register_parent(client)
    headers = auth_headers(parent["accessToken"])
    created = await client.put(f"/api/students/{parent['studentProfileId']}", headers=headers, json={
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
    assert courses == []
