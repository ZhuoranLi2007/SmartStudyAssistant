import json

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai import ChatOrchestrator
from server.database import get_db
from server.models import ChatMessage, ChatSession, User
from server.schemas import ChatRequest
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("")
async def chat(payload: ChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await ChatOrchestrator(db, user).handle(payload.student_profile_id, payload.message, payload.session_id)
    return ok(result)


@router.post("/stream")
async def stream_chat(payload: ChatRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await ChatOrchestrator(db, user).handle(payload.student_profile_id, payload.message, payload.session_id)

    async def event_stream():
        yield f"event: message\ndata: {json.dumps(result, ensure_ascii=False)}\n\n"
        yield "event: done\ndata: {}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@router.get("/history/{session_id}")
async def history(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    session = await db.get(ChatSession, session_id)
    if session is None or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="会话不存在")
    rows = list((await db.scalars(select(ChatMessage).where(
        ChatMessage.session_id == session_id
    ).order_by(ChatMessage.created_at))).all())
    return ok({"sessionId": session.id, "summary": session.summary,
               "messages": [{"id": row.id, "role": row.role, "content": row.content,
                             "intent": row.intent, "createTime": row.created_at.isoformat()} for row in rows]})


@router.delete("/history/{session_id}")
async def clear_history(session_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    session = await db.get(ChatSession, session_id)
    if session is None or session.user_id != user.id:
        raise HTTPException(status_code=404, detail="会话不存在")
    await db.execute(delete(ChatMessage).where(ChatMessage.session_id == session_id))
    session.summary = ""
    session.context_json = {}
    await db.commit()
    return ok(None, "会话已清空")
