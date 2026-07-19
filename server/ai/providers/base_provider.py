from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class ProviderResult:
    content: str
    model: str
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
        messages: list[dict[str, str]],
        *,
        json_mode: bool = False,
        fallback_content: str = "",
    ) -> ProviderResult:
        raise NotImplementedError

    @abstractmethod
    async def stream(
        self,
        messages: list[dict[str, str]],
        *,
        fallback_content: str = "",
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
