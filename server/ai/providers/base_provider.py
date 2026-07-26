from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class ProviderToolCall:
    id: str
    name: str
    arguments: dict[str, Any]


@dataclass(slots=True)
class ProviderResult:
    content: str
    model: str
    tool_calls: list[ProviderToolCall] = field(default_factory=list)
    usage: dict[str, int] = field(default_factory=dict)
    latency_ms: int = 0
    fallback_used: bool = False
    error_code: str = ""


class ProviderError(RuntimeError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


class AIProvider(ABC):
    name: str
    model: str

    @property
    @abstractmethod
    def configured(self) -> bool:
        raise NotImplementedError

    @abstractmethod
    async def complete(
        self,
        messages: list[dict[str, Any]],
        *,
        json_mode: bool = False,
        fallback_content: str = "",
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str | dict[str, Any] | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> ProviderResult:
        raise NotImplementedError

    @abstractmethod
    async def stream(
        self,
        messages: list[dict[str, Any]],
        *,
        fallback_content: str = "",
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> AsyncIterator[str]:
        raise NotImplementedError


def safe_usage(value: Any) -> dict[str, int]:
    if value is None:
        return {}
    result: dict[str, int] = {}
    for source, target in (
        ("prompt_tokens", "promptTokens"),
        ("completion_tokens", "completionTokens"),
        ("total_tokens", "totalTokens"),
    ):
        item = getattr(value, source, None)
        if isinstance(item, int):
            result[target] = item
    return result
