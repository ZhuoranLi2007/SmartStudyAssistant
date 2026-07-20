from collections.abc import Awaitable, Callable
from time import perf_counter

from sqlalchemy.ext.asyncio import AsyncSession

from server.models import ToolCallLog
from server.tools.base_tool import BusinessTool, ToolContext

ToolHandler = Callable[[dict], Awaitable[dict]]


class ToolRegistry:
    def __init__(self, db: AsyncSession, session_id: str | None, request_id: str = "", context: ToolContext | None = None):
        self.db = db
        self.session_id = session_id
        self.request_id = request_id
        self.context = context
        self.handlers: dict[str, ToolHandler] = {}
        self.tools: dict[str, BusinessTool] = {}

    def register(self, name: str, handler: ToolHandler) -> None:
        self.handlers[name] = handler

    def register_tool(self, tool: BusinessTool) -> None:
        self.tools[tool.name] = tool

    def definitions(self) -> list[dict]:
        return [{"name": item.name, "description": item.description, "inputSchema": item.input_schema} for item in self.tools.values()]

    async def execute(self, name: str, arguments: dict) -> dict:
        tool = self.tools.get(name)
        if tool is None and name not in self.handlers:
            raise ValueError(f"未注册工具: {name}")
        started = perf_counter()
        success = True
        error_summary = ""
        error_code = ""
        try:
            if tool is not None:
                if self.context is None:
                    raise RuntimeError("业务工具缺少执行上下文")
                tool.validate(arguments)
                return await tool.execute(self.context, arguments)
            return await self.handlers[name](arguments)
        except Exception as exc:
            success = False
            error_summary = str(exc)[:255]
            error_code = exc.__class__.__name__[:50]
            raise
        finally:
            self.db.add(ToolCallLog(
                session_id=self.session_id,
                tool_name=name,
                arguments_json=arguments,
                success=success,
                duration_ms=int((perf_counter() - started) * 1000),
                error_summary=error_summary,
                request_id=self.request_id,
                status="completed" if success else "failed",
                error_code=error_code,
            ))
