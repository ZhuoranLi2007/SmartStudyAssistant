from collections.abc import AsyncIterator

from server.ai.providers.base_provider import AIProvider, ProviderError, ProviderResult
from server.ai.providers.deepseek_provider import DeepSeekProvider
from server.ai.providers.mock_provider import MockProvider
from server.config import Settings, get_settings


class ProviderRouter:
    def __init__(self, settings: Settings | None = None):
        self.settings = settings or get_settings()
        self.mock = MockProvider()
        self.deepseek = DeepSeekProvider(
            self.settings.deepseek_api_key,
            self.settings.deepseek_base_url,
            self.settings.deepseek_model,
            self.settings.ai_request_timeout,
            self.settings.ai_temperature,
        )

    @property
    def provider(self) -> AIProvider:
        if not self.settings.ai_enabled or self.settings.ai_provider.lower() == "mock":
            return self.mock
        return self.deepseek

    @property
    def configured(self) -> bool:
        return self.deepseek.configured

    async def complete(
        self,
        messages: list[dict[str, str]],
        *,
        json_mode: bool = False,
        fallback_content: str = "",
    ) -> ProviderResult:
        provider = self.provider
        try:
            return await provider.complete(messages, json_mode=json_mode, fallback_content=fallback_content)
        except ProviderError:
            if not self.settings.ai_mock_fallback:
                raise
            return await self.mock.complete(messages, json_mode=json_mode, fallback_content=fallback_content)

    async def stream(
        self,
        messages: list[dict[str, str]],
        *,
        fallback_content: str = "",
    ) -> AsyncIterator[str]:
        provider = self.provider
        received = False
        try:
            async for delta in provider.stream(messages, fallback_content=fallback_content):
                received = True
                yield delta
        except ProviderError:
            if not self.settings.ai_mock_fallback or received:
                raise
            async for delta in self.mock.stream(messages, fallback_content=fallback_content):
                yield delta
