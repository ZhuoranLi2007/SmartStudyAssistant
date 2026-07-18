from collections.abc import Awaitable, Callable
from time import perf_counter

from sqlalchemy.ext.asyncio import AsyncSession

from server.models import ToolCallLog

ToolHandler = Callable[[dict], Awaitable[dict]]


class ToolRegistry:
    def __init__(self, db: AsyncSession, session_id: str | None):
        self.db = db
        self.session_id = session_id
        self.handlers: dict[str, ToolHandler] = {}

    def register(self, name: str, handler: ToolHandler) -> None:
        self.handlers[name] = handler

    async def execute(self, name: str, arguments: dict) -> dict:
        if name not in self.handlers:
            raise ValueError(f"未注册工具: {name}")
        started = perf_counter()
        success = True
        error_summary = ""
        try:
            return await self.handlers[name](arguments)
        except Exception as exc:
            success = False
            error_summary = str(exc)[:255]
            raise
        finally:
            self.db.add(ToolCallLog(
                session_id=self.session_id,
                tool_name=name,
                arguments_json=arguments,
                success=success,
                duration_ms=int((perf_counter() - started) * 1000),
                error_summary=error_summary,
            ))
