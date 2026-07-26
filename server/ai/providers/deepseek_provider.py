import json
from collections.abc import AsyncIterator
from time import perf_counter
from typing import Any

from openai import APIConnectionError, APIStatusError, APITimeoutError, AsyncOpenAI, AuthenticationError, RateLimitError

from server.ai.providers.base_provider import AIProvider, ProviderError, ProviderResult, ProviderToolCall, safe_usage


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
        messages: list[dict[str, Any]],
        *,
        json_mode: bool = False,
        fallback_content: str = "",
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str | dict[str, Any] | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> ProviderResult:
        if self._client is None:
            raise ProviderError("AI_NOT_CONFIGURED", "DeepSeek API Key 尚未配置")
        started = perf_counter()
        try:
            request: dict = {
                "model": self.model,
                "messages": messages,
                "temperature": self.temperature if temperature is None else temperature,
                "max_tokens": max_tokens or (1200 if json_mode else 2000),
                "extra_body": {"thinking": {"type": "disabled"}},
            }
            if json_mode:
                request["response_format"] = {"type": "json_object"}
            if tools:
                request["tools"] = tools
                request["tool_choice"] = tool_choice or "auto"
            response = await self._client.chat.completions.create(
                **request,
            )
            message = response.choices[0].message
            content = message.content or ""
            parsed_calls: list[ProviderToolCall] = []
            for call in message.tool_calls or []:
                try:
                    arguments = json.loads(call.function.arguments or "{}")
                    if not isinstance(arguments, dict):
                        raise ValueError("工具参数必须为 JSON 对象")
                except (TypeError, ValueError, json.JSONDecodeError) as exc:
                    raise ProviderError("AI_INVALID_TOOL_ARGUMENTS", f"DeepSeek 工具参数无效：{call.function.name}") from exc
                parsed_calls.append(ProviderToolCall(id=call.id, name=call.function.name, arguments=arguments))
            if not content.strip() and not parsed_calls:
                raise ProviderError("AI_EMPTY_RESPONSE", "DeepSeek 返回了空内容")
            return ProviderResult(
                content=content.strip(),
                model=response.model or self.model,
                tool_calls=parsed_calls,
                usage=safe_usage(response.usage),
                latency_ms=int((perf_counter() - started) * 1000),
            )
        except ProviderError:
            raise
        except Exception as exc:
            raise self._error(exc) from exc

    async def stream(
        self,
        messages: list[dict[str, Any]],
        *,
        fallback_content: str = "",
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> AsyncIterator[str]:
        if self._client is None:
            raise ProviderError("AI_NOT_CONFIGURED", "DeepSeek API Key 尚未配置")
        try:
            response = await self._client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=self.temperature if temperature is None else temperature,
                max_tokens=max_tokens or 2000,
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
