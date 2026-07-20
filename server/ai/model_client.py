"""旧模型客户端的兼容导出。

新代码统一使用 ProviderRouter；保留这些类是为了避免旧导入立即失效。
"""

import json
from abc import ABC, abstractmethod

from server.ai.providers import ProviderRouter


class ModelClient(ABC):
    @abstractmethod
    async def compose(self, intent: str, tool_result: dict) -> str:
        raise NotImplementedError


class MockModelClient(ModelClient):
    async def compose(self, intent: str, tool_result: dict) -> str:
        recommendation = tool_result.get("recommendation")
        if recommendation:
            return str(recommendation.get("explanation") or "已完成课程推荐。")
        return "我可以帮助分析学情、推荐课程和试卷。"


class OpenAICompatibleModelClient(ModelClient):
    async def compose(self, intent: str, tool_result: dict) -> str:
        fallback = "已根据业务数据完成处理，请查看结构化结果。"
        result = await ProviderRouter().complete([
            {"role": "system", "content": "请根据业务工具结果生成简洁教育建议，不得修改事实字段。"},
            {"role": "user", "content": json.dumps({"intent": intent, "toolResult": tool_result}, ensure_ascii=False)},
        ], fallback_content=fallback)
        return result.content
