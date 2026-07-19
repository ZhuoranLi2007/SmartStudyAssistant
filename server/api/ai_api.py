import json
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai import AIOrchestrator
from server.ai.memory import ConversationMemoryService
from server.ai.providers import ProviderRouter
from server.ai.rag import RAGService
from server.config import get_settings
from server.database import get_db
from server.models import StudentProfile, User
from server.schemas import AIChatRequest
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/ai", tags=["ai"])


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"


def _missing_profile_result() -> dict:
    request_id = str(uuid4())
    answer = "当前账号还没有有效的学生档案，请先填写年级、成绩、薄弱知识点和学习目标，再使用个性化 AI 顾问。"
    return {
        "sessionId": "",
        "intent": "STUDENT_ANALYSIS",
        "confidence": 1.0,
        "answer": answer,
        "assistantMessage": answer,
        "missingFields": ["studentProfile"],
        "clarification": answer,
        "toolCalls": [],
        "cards": [],
        "sources": [],
        "fallbackUsed": False,
        "requestId": request_id,
    }


@router.get("/health")
async def ai_health():
    settings = get_settings()
    provider = ProviderRouter(settings)
    return ok({
        "enabled": settings.ai_enabled,
        "requestedProvider": settings.ai_provider,
        "activeProvider": provider.provider.name,
        "model": provider.provider.model,
        "deepseekConfigured": provider.configured,
        "mockFallbackEnabled": settings.ai_mock_fallback,
    })


@router.post("/chat")
async def ai_chat(payload: AIChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if payload.student_profile_id <= 0 or await db.get(StudentProfile, payload.student_profile_id) is None:
        return ok(_missing_profile_result())
    result = await AIOrchestrator(db, user).handle(
        payload.student_profile_id, payload.message, payload.session_id,
        payload.client_message_id, payload.user_id,
    )
    return ok(result)


@router.post("/chat/stream")
async def ai_chat_stream(payload: AIChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if payload.student_profile_id <= 0 or await db.get(StudentProfile, payload.student_profile_id) is None:
        result = _missing_profile_result()

        async def missing_profile_events():
            yield _sse("meta", {"requestId": result["requestId"], "sessionId": ""})
            yield _sse("intent", {"intent": result["intent"], "confidence": 1.0})
            yield _sse("delta", {"content": result["answer"]})
            yield _sse("done", result)

        return StreamingResponse(missing_profile_events(), media_type="text/event-stream")
    orchestrator = AIOrchestrator(db, user)

    async def events():
        try:
            async for event, data in orchestrator.stream(
                payload.student_profile_id, payload.message, payload.session_id,
                payload.client_message_id, payload.user_id,
            ):
                yield _sse(event, data)
        except HTTPException as exc:
            yield _sse("error", {"code": exc.status_code, "message": str(exc.detail)})
        except Exception:
            yield _sse("error", {"code": "AI_STREAM_FAILED", "message": "AI 流式响应暂时不可用"})

    return StreamingResponse(events(), media_type="text/event-stream", headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


@router.get("/sessions/{session_id}/messages")
async def session_messages(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return ok(await ConversationMemoryService(db, user).history(session_id))


@router.delete("/sessions/{session_id}")
async def clear_session(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await ConversationMemoryService(db, user).clear(session_id)
    await db.commit()
    return ok(None, "会话已清空")


@router.post("/rag/rebuild")
async def rebuild_rag(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    settings = get_settings()
    if settings.environment.lower() not in {"development", "dev", "test"}:
        raise HTTPException(status_code=403, detail="RAG 重建仅在开发环境开放")
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="只有家长账号可以重建知识库")
    result = await RAGService(db).rebuild()
    await db.commit()
    return ok(result, "知识库已重建")
