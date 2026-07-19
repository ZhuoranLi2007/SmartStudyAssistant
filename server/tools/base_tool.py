from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from server.models import StudentProfile, User


@dataclass(slots=True)
class ToolContext:
    db: AsyncSession
    user: User
    student: StudentProfile
    session_id: str
    request_id: str


class BusinessTool(ABC):
    name: str
    description: str
    input_schema: dict[str, Any]

    def validate(self, arguments: dict[str, Any]) -> None:
        required = self.input_schema.get("required", [])
        missing = [item for item in required if arguments.get(item) is None]
        if missing:
            raise ValueError(f"工具 {self.name} 缺少参数：{','.join(missing)}")

    @abstractmethod
    async def execute(self, context: ToolContext, arguments: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError
