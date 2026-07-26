import json
from collections.abc import AsyncIterator
from typing import Any

from server.ai.providers.base_provider import AIProvider, ProviderResult


class MockProvider(AIProvider):
    name = "mock"
    model = "smartstudy-mock"

    @property
    def configured(self) -> bool:
        return True

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
        if json_mode:
            content = fallback_content or json.dumps({"intent": "UNKNOWN", "confidence": 0.2}, ensure_ascii=False)
        else:
            content = fallback_content or "当前使用本地演示回答。请完善学生档案后再进行课程和试卷推荐。"
        return ProviderResult(content=content, model=self.model, fallback_used=True)

    async def stream(
        self,
        messages: list[dict[str, Any]],
        *,
        fallback_content: str = "",
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> AsyncIterator[str]:
        result = await self.complete(messages, fallback_content=fallback_content)
        text = result.content
        step = 12
        for index in range(0, len(text), step):
            yield text[index:index + step]
