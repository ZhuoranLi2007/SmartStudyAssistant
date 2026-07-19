from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import get_settings
from server.models import ChatMessage, ChatSession, User


class ConversationMemoryService:
    def __init__(self, db: AsyncSession, user: User):
        self.db = db
        self.user = user
        self.limit = get_settings().ai_max_history_messages

    async def get_or_create(self, student_profile_id: int, session_id: str | None = None) -> ChatSession:
        if session_id:
            session = await self.db.get(ChatSession, session_id)
            if session is None or session.user_id != self.user.id or session.student_profile_id != student_profile_id:
                raise HTTPException(status_code=404, detail="会话不存在")
            return session
        session = ChatSession(
            id=str(uuid4()),
            user_id=self.user.id,
            student_profile_id=student_profile_id,
            title="学习咨询",
            summary="",
            context_json={},
        )
        self.db.add(session)
        await self.db.flush()
        return session

    async def recent_messages(self, session: ChatSession) -> list[dict[str, str]]:
        rows = list((await self.db.scalars(
            select(ChatMessage)
            .where(ChatMessage.session_id == session.id)
            .order_by(ChatMessage.created_at.desc(), ChatMessage.id.desc())
            .limit(self.limit)
        )).all())
        rows.reverse()
        messages: list[dict[str, str]] = []
        if session.summary:
            messages.append({"role": "system", "content": f"历史摘要：{session.summary}"})
        messages.extend({"role": row.role, "content": row.content} for row in rows)
        return messages

    def add_message(
        self,
        session: ChatSession,
        role: str,
        content: str,
        intent: str,
        client_message_id: str | None = None,
        tool_calls: list[dict] | None = None,
        model_metadata: dict | None = None,
    ) -> ChatMessage:
        row = ChatMessage(
            session_id=session.id,
            role=role,
            content=content,
            intent=intent,
            client_message_id=client_message_id,
            tool_calls_json=tool_calls or [],
            model_metadata_json=model_metadata or {},
        )
        self.db.add(row)
        return row

    async def summarize_if_needed(self, session: ChatSession) -> None:
        count = await self.db.scalar(select(func.count(ChatMessage.id)).where(ChatMessage.session_id == session.id)) or 0
        if count <= self.limit:
            return
        context = session.context_json or {}
        parts = [f"会话共{count}条消息"]
        mapping = {
            "grade": "年级",
            "subject": "学科",
            "score": "成绩",
            "weakPoints": "薄弱点",
            "learningGoal": "学习目标",
        }
        for key, label in mapping.items():
            value = context.get(key)
            if value not in (None, "", []):
                parts.append(f"{label}={value}")
        session.summary = "；".join(parts)[:2000]

    async def history(self, session_id: str) -> dict:
        session = await self.db.get(ChatSession, session_id)
        if session is None or session.user_id != self.user.id:
            raise HTTPException(status_code=404, detail="会话不存在")
        rows = list((await self.db.scalars(
            select(ChatMessage).where(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at, ChatMessage.id)
        )).all())
        return {
            "sessionId": session.id,
            "studentProfileId": session.student_profile_id,
            "summary": session.summary,
            "messages": [{
                "id": row.id,
                "role": row.role,
                "content": row.content,
                "intent": row.intent,
                "clientMessageId": row.client_message_id,
                "toolCalls": row.tool_calls_json,
                "modelMetadata": row.model_metadata_json,
                "createTime": row.created_at.isoformat(),
            } for row in rows],
        }

    async def clear(self, session_id: str) -> None:
        session = await self.db.get(ChatSession, session_id)
        if session is None or session.user_id != self.user.id:
            raise HTTPException(status_code=404, detail="会话不存在")
        await self.db.execute(delete(ChatMessage).where(ChatMessage.session_id == session.id))
        session.summary = ""
        session.context_json = {}
