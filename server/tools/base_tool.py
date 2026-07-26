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
        if not isinstance(arguments, dict):
            raise ValueError(f"工具 {self.name} 参数必须是对象")
        properties = self.input_schema.get("properties", {})
        if self.input_schema.get("additionalProperties") is False:
            unknown = sorted(set(arguments) - set(properties))
            if unknown:
                raise ValueError(f"工具 {self.name} 包含未知参数：{','.join(unknown)}")
        required = self.input_schema.get("required", [])
        missing = [item for item in required if arguments.get(item) is None]
        if missing:
            raise ValueError(f"工具 {self.name} 缺少参数：{','.join(missing)}")
        for key, value in arguments.items():
            if value is None or key not in properties:
                continue
            schema = properties[key]
            expected = schema.get("type")
            valid = {
                "string": isinstance(value, str),
                "integer": isinstance(value, int) and not isinstance(value, bool),
                "number": isinstance(value, (int, float)) and not isinstance(value, bool),
                "boolean": isinstance(value, bool),
                "array": isinstance(value, list),
                "object": isinstance(value, dict),
            }.get(expected, True)
            if not valid:
                raise ValueError(f"工具 {self.name} 参数 {key} 类型无效")
            if "enum" in schema and value not in schema["enum"]:
                raise ValueError(f"工具 {self.name} 参数 {key} 不在允许范围内")
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                if "minimum" in schema and value < schema["minimum"]:
                    raise ValueError(f"工具 {self.name} 参数 {key} 小于最小值")
                if "maximum" in schema and value > schema["maximum"]:
                    raise ValueError(f"工具 {self.name} 参数 {key} 超过最大值")
            if isinstance(value, list) and schema.get("items", {}).get("type") == "string":
                if not all(isinstance(item, str) for item in value):
                    raise ValueError(f"工具 {self.name} 参数 {key} 数组元素类型无效")
                item_enum = schema.get("items", {}).get("enum")
                if item_enum and any(item not in item_enum for item in value):
                    raise ValueError(f"工具 {self.name} 参数 {key} 数组元素不在允许范围内")

    @abstractmethod
    async def execute(self, context: ToolContext, arguments: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError
