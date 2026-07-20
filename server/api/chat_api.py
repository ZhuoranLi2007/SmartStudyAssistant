import json

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai import AIOrchestrator
from server.ai.memory import ConversationMemoryService
from server.database import get_db
from server.models import User
from server.schemas import ChatRequest
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/chat", tags=["chat-compatibility"])


@router.post("")
async def chat(payload: ChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return ok(await AIOrchestrator(db, user).handle(payload.student_profile_id, payload.message, payload.session_id))


@router.post("/stream")
async def stream_chat(payload: ChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    orchestrator = AIOrchestrator(db, user)

    async def event_stream():
        try:
            async for event, data in orchestrator.stream(payload.student_profile_id, payload.message, payload.session_id):
                yield f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"
        except HTTPException as exc:
            yield f"event: error\ndata: {json.dumps({'code': exc.status_code, 'message': str(exc.detail)}, ensure_ascii=False)}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream", headers={"Cache-Control": "no-cache"})


@router.get("/history/{session_id}")
async def history(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return ok(await ConversationMemoryService(db, user).history(session_id))


@router.delete("/history/{session_id}")
async def clear_history(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await ConversationMemoryService(db, user).clear(session_id)
    await db.commit()
    return ok(None, "会话已清空")
