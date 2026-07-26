import json
import logging
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai import AIOrchestrator
from server.ai.intent import IntentType
from server.ai.intent.intent_classifier import classify_by_rules
from server.ai.memory import ConversationMemoryService
from server.ai.orchestrator import SYSTEM_PROMPT
from server.ai.providers import ProviderError, ProviderRouter
from server.ai.rag import RAGService
from server.config import get_settings
from server.database import get_db
from server.models import StudentProfile, User
from server.schemas import AIChatRequest, AISessionCreate
from server.services.access_service import ensure_student_access
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/ai", tags=["ai"])
logger = logging.getLogger("smartstudy.ai.api")


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"


def _missing_profile_result(intent: str = "STUDENT_ANALYSIS") -> dict:
    request_id = str(uuid4())
    answer = "当前账号还没有有效的学生档案，请先填写年级、成绩、薄弱知识点和学习目标，再使用个性化 AI 顾问。"
    return {
        "sessionId": "",
        "intent": intent,
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


async def _without_student_result(payload: AIChatRequest, db: AsyncSession) -> dict:
    intent = classify_by_rules(payload.message)
    if intent.intent not in {IntentType.GENERAL_CHAT, IntentType.KNOWLEDGE_QA, IntentType.UNKNOWN}:
        return _missing_profile_result(intent.intent.value)
    sources = await RAGService(db).search(payload.message)
    safe_sources = [
        {key: value for key, value in source.items() if key != "content"} | {"excerpt": source["content"][:180]}
        for source in sources
    ]
    fallback = "我可以先回答通用学习问题。创建或绑定学生档案后，还能获得个性化课程、试卷和学习计划建议。"
    evidence = json.dumps([
        {"title": source.get("title", ""), "content": source.get("content", "")[:500]}
        for source in sources
    ], ensure_ascii=False)
    provider = ProviderRouter()
    try:
        result = await provider.complete([
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "system", "content": f"当前未绑定学生档案，只能回答通用教育问题。参考资料：{evidence}"},
            {"role": "user", "content": payload.message},
        ], fallback_content=fallback)
        answer = result.content or fallback
        fallback_used = result.fallback_used or result.model.startswith("mock")
    except ProviderError:
        answer = fallback
        fallback_used = True
    return {
        "sessionId": "",
        "intent": intent.intent.value,
        "confidence": intent.confidence,
        "answer": answer,
        "assistantMessage": answer,
        "missingFields": [],
        "clarificationQuestion": None,
        "toolCalls": [],
        "cards": [],
        "sources": safe_sources,
        "fallbackUsed": fallback_used,
        "requestId": str(uuid4()),
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
        return ok(await _without_student_result(payload, db))
    try:
        result = await AIOrchestrator(db, user).handle(
            payload.student_profile_id, payload.message, payload.session_id,
            payload.client_message_id, payload.user_id,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception(
            "AI chat failed client_message_id=%s student_profile_id=%s error_type=%s",
            payload.client_message_id,
            payload.student_profile_id,
            exc.__class__.__name__,
        )
        raise HTTPException(status_code=503, detail="智能服务处理失败，请稍后重试") from exc
    return ok(result)


@router.post("/chat/stream")
async def ai_chat_stream(payload: AIChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if payload.student_profile_id <= 0 or await db.get(StudentProfile, payload.student_profile_id) is None:
        result = await _without_student_result(payload, db)

        async def missing_profile_events():
            yield _sse("meta", {"requestId": result["requestId"], "sessionId": ""})
            yield _sse("intent", {"intent": result["intent"], "confidence": result["confidence"]})
            for source in result["sources"]:
                yield _sse("source", source)
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
        except Exception as exc:
            logger.exception(
                "AI stream failed client_message_id=%s student_profile_id=%s error_type=%s",
                payload.client_message_id,
                payload.student_profile_id,
                exc.__class__.__name__,
            )
            yield _sse("error", {"code": "AI_STREAM_FAILED", "message": "AI 流式响应暂时不可用"})

    return StreamingResponse(events(), media_type="text/event-stream", headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


@router.get("/sessions/{session_id}/messages")
async def session_messages(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return ok(await ConversationMemoryService(db, user).history(session_id))


@router.get("/sessions")
async def list_sessions(
    student_profile_id: int | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if student_profile_id is not None:
        await ensure_student_access(db, user, student_profile_id)
    return ok(await ConversationMemoryService(db, user).list_sessions(student_profile_id))


@router.post("/sessions")
async def create_session(
    payload: AISessionCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, payload.student_profile_id)
    result = await ConversationMemoryService(db, user).create_session(payload.student_profile_id)
    await db.commit()
    return ok(result, "会话已创建")


@router.post("/sessions/{session_id}/clear")
async def clear_session_messages(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    memory = ConversationMemoryService(db, user)
    await memory.clear(session_id)
    await db.commit()
    return ok({"sessionId": session_id, "updatedAt": datetime.now(timezone.utc).isoformat()}, "会话已清空")


@router.delete("/sessions/{session_id}")
async def clear_session(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await ConversationMemoryService(db, user).delete_session(session_id)
    await db.commit()
    return ok({"sessionId": session_id, "deletedAt": datetime.now(timezone.utc).isoformat()}, "会话已删除")


@router.post("/rag/rebuild")
async def rebuild_rag(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    settings = get_settings()
    if settings.environment.lower() not in {"development", "dev", "test"}:
        raise HTTPException(status_code=403, detail="RAG 重建仅在开发环境开放")
    # 当前注册流程统一使用 user 角色并创建家庭学习空间；开发环境允许该空间所有者维护 RAG。
    if user.role not in {"user", "parent"}:
        raise HTTPException(status_code=403, detail="只有家庭学习空间账号可以重建知识库")
    result = await RAGService(db).rebuild()
    await db.commit()
    return ok(result, "知识库已重建")
