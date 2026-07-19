from collections.abc import AsyncIterator
from time import perf_counter

from openai import APIConnectionError, APIStatusError, APITimeoutError, AsyncOpenAI, AuthenticationError, RateLimitError

from server.ai.providers.base_provider import AIProvider, ProviderError, ProviderResult, safe_usage


class DeepSeekProvider(AIProvider):
    name = "deepseek"

    def __init__(self, api_key: str, base_url: str, model: str, timeout: float, temperature: float):
        self.api_key = api_key.strip()
        self.base_url = base_url
        self.model = model
        self.timeout = timeout
        self.temperature = temperature
        self._client = AsyncOpenAI(api_key=self.api_key, base_url=base_url, timeout=timeout) if self.api_key else None

    @property
    def configured(self) -> bool:
        return self._client is not None

    def _error(self, exc: Exception) -> ProviderError:
        if isinstance(exc, AuthenticationError):
            return ProviderError("AI_AUTH_FAILED", "DeepSeek 认证失败，请检查服务端配置")
        if isinstance(exc, RateLimitError):
            return ProviderError("AI_RATE_LIMITED", "DeepSeek 请求过于频繁，请稍后重试")
        if isinstance(exc, APITimeoutError):
            return ProviderError("AI_TIMEOUT", "DeepSeek 请求超时")
        if isinstance(exc, APIConnectionError):
            return ProviderError("AI_NETWORK_ERROR", "无法连接 DeepSeek 服务")
        if isinstance(exc, APIStatusError):
            return ProviderError("AI_PROVIDER_ERROR", f"DeepSeek 服务返回异常状态 {exc.status_code}")
        return ProviderError("AI_PROVIDER_ERROR", "DeepSeek 服务暂时不可用")

    async def complete(
        self,
        messages: list[dict[str, str]],
        *,
        json_mode: bool = False,
        fallback_content: str = "",
    ) -> ProviderResult:
        if self._client is None:
            raise ProviderError("AI_NOT_CONFIGURED", "DeepSeek API Key 尚未配置")
        started = perf_counter()
        try:
            request: dict = {
                "model": self.model,
                "messages": messages,
                "temperature": self.temperature,
                "max_tokens": 1200 if json_mode else 2000,
                "extra_body": {"thinking": {"type": "disabled"}},
            }
            if json_mode:
                request["response_format"] = {"type": "json_object"}
            response = await self._client.chat.completions.create(
                **request,
            )
            content = response.choices[0].message.content or ""
            if not content.strip():
                raise ProviderError("AI_EMPTY_RESPONSE", "DeepSeek 返回了空内容")
            return ProviderResult(
                content=content.strip(),
                model=response.model or self.model,
                usage=safe_usage(response.usage),
                latency_ms=int((perf_counter() - started) * 1000),
            )
        except ProviderError:
            raise
        except Exception as exc:
            raise self._error(exc) from exc

    async def stream(
        self,
        messages: list[dict[str, str]],
        *,
        fallback_content: str = "",
    ) -> AsyncIterator[str]:
        if self._client is None:
            raise ProviderError("AI_NOT_CONFIGURED", "DeepSeek API Key 尚未配置")
        try:
            response = await self._client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=self.temperature,
                max_tokens=2000,
                extra_body={"thinking": {"type": "disabled"}},
                stream=True,
            )
            received = False
            async for chunk in response:
                delta = chunk.choices[0].delta.content or ""
                if delta:
                    received = True
                    yield delta
            if not received:
                raise ProviderError("AI_EMPTY_RESPONSE", "DeepSeek 返回了空内容")
        except ProviderError:
            raise
        except Exception as exc:
            raise self._error(exc) from exc
