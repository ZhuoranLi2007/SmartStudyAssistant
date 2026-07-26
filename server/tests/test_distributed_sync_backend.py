import asyncio
import uuid
from unittest.mock import AsyncMock, patch

import pytest

from server.database import SessionLocal
from server.models import Paper


async def register_parent(client, prefix: str) -> dict:
    suffix = uuid.uuid4().hex[:8]
    response = await client.post("/api/auth/register", json={
        "username": f"{prefix}_{suffix}",
        "phone": f"138{suffix}",
        "password": "secret123",
        "role": "parent",
    })
    assert response.status_code == 200, response.text
    return response.json()["data"]


def headers(account: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {account['accessToken']}"}


@pytest.mark.asyncio
async def test_ai_session_lifecycle_and_account_isolation(client):
    owner = await register_parent(client, "session_owner")
    stranger = await register_parent(client, "session_other")

    created = await client.post("/api/ai/sessions", headers=headers(owner), json={
        "studentProfileId": owner["studentProfileId"],
    })
    assert created.status_code == 200, created.text
    session = created.json()["data"]
    assert session["sessionId"]
    assert session["messageCount"] == 0
    assert session["updatedAt"]

    listing = await client.get(
        "/api/ai/sessions",
        headers=headers(owner),
        params={"student_profile_id": owner["studentProfileId"]},
    )
    assert listing.status_code == 200, listing.text
    assert [item["sessionId"] for item in listing.json()["data"]] == [session["sessionId"]]

    history = await client.get(f"/api/ai/sessions/{session['sessionId']}/messages", headers=headers(owner))
    assert history.status_code == 200
    assert history.json()["data"]["messages"] == []

    forbidden_history = await client.get(
        f"/api/ai/sessions/{session['sessionId']}/messages",
        headers=headers(stranger),
    )
    assert forbidden_history.status_code == 404

    cleared = await client.post(f"/api/ai/sessions/{session['sessionId']}/clear", headers=headers(owner))
    assert cleared.status_code == 200
    assert cleared.json()["data"]["sessionId"] == session["sessionId"]
    assert cleared.json()["data"]["updatedAt"]

    deleted = await client.delete(f"/api/ai/sessions/{session['sessionId']}", headers=headers(owner))
    assert deleted.status_code == 200
    assert deleted.json()["data"]["sessionId"] == session["sessionId"]
    assert deleted.json()["data"]["deletedAt"]

    missing = await client.get(f"/api/ai/sessions/{session['sessionId']}/messages", headers=headers(owner))
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_ai_user_message_is_committed_before_agent_preparation_fails(client):
    owner = await register_parent(client, "early_commit")
    client_message_id = f"early-{uuid.uuid4().hex[:12]}"

    with patch(
        "server.ai.orchestrator.AIOrchestrator._student_snapshot",
        new=AsyncMock(side_effect=RuntimeError("simulated preparation failure")),
    ):
        response = await client.post("/api/ai/chat", headers=headers(owner), json={
            "studentProfileId": owner["studentProfileId"],
            "message": "应用题比较弱",
            "clientMessageId": client_message_id,
        })
    assert response.status_code == 503

    sessions = await client.get(
        "/api/ai/sessions",
        headers=headers(owner),
        params={"student_profile_id": owner["studentProfileId"]},
    )
    assert sessions.status_code == 200
    assert len(sessions.json()["data"]) == 1
    session_id = sessions.json()["data"][0]["sessionId"]

    history = await client.get(f"/api/ai/sessions/{session_id}/messages", headers=headers(owner))
    assert history.status_code == 200
    messages = history.json()["data"]["messages"]
    assert len(messages) == 1
    assert messages[0]["role"] == "user"
    assert messages[0]["clientMessageId"] == client_message_id


@pytest.mark.asyncio
async def test_concurrent_client_message_id_creates_one_message_pair(client):
    owner = await register_parent(client, "concurrent")
    created = await client.post("/api/ai/sessions", headers=headers(owner), json={
        "studentProfileId": owner["studentProfileId"],
    })
    session_id = created.json()["data"]["sessionId"]
    client_message_id = f"same-{uuid.uuid4().hex[:12]}"
    payload = {
        "studentProfileId": owner["studentProfileId"],
        "sessionId": session_id,
        "message": "请分析我目前的学习情况",
        "clientMessageId": client_message_id,
    }

    first, second = await asyncio.gather(
        client.post("/api/ai/chat", headers=headers(owner), json=payload),
        client.post("/api/ai/chat", headers=headers(owner), json=payload),
    )
    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text
    assert first.json()["data"]["requestId"] == second.json()["data"]["requestId"]

    history = await client.get(f"/api/ai/sessions/{session_id}/messages", headers=headers(owner))
    assert history.status_code == 200
    messages = history.json()["data"]["messages"]
    assert [(item["role"], item["clientMessageId"]) for item in messages] == [
        ("user", client_message_id),
        ("assistant", client_message_id),
    ]


@pytest.mark.asyncio
async def test_private_ai_paper_is_visible_only_to_creator(client):
    owner = await register_parent(client, "paper_owner")
    stranger = await register_parent(client, "paper_other")
    async with SessionLocal() as db:
        paper = Paper(
            name=f"权限测试-{uuid.uuid4().hex}",
            grade="六年级",
            subject="数学",
            difficulty="基础",
            knowledge_points=["应用题"],
            question_count=0,
            suitable_course_level="AI组卷",
            is_ai_generated=True,
            created_by=owner["user"]["id"],
            is_active=True,
        )
        db.add(paper)
        await db.commit()
        paper_id = paper.id

    owner_detail = await client.get(f"/api/papers/{paper_id}", headers=headers(owner))
    owner_questions = await client.get(f"/api/papers/{paper_id}/questions", headers=headers(owner))
    assert owner_detail.status_code == 200
    assert owner_questions.status_code == 200

    stranger_detail = await client.get(f"/api/papers/{paper_id}", headers=headers(stranger))
    stranger_questions = await client.get(f"/api/papers/{paper_id}/questions", headers=headers(stranger))
    assert stranger_detail.status_code == 403
    assert stranger_questions.status_code == 403

    stranger_attempt = await client.post(f"/api/papers/{paper_id}/attempts", headers=headers(stranger), json={
        "studentProfileId": stranger["studentProfileId"],
        "answers": [{"questionId": 1, "selectedIndex": 0}],
    })
    assert stranger_attempt.status_code == 403
