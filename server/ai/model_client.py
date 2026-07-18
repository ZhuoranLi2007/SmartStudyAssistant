from abc import ABC, abstractmethod


class ModelClient(ABC):
    @abstractmethod
    async def compose(self, intent: str, tool_result: dict) -> str:
        raise NotImplementedError


class MockModelClient(ModelClient):
    async def compose(self, intent: str, tool_result: dict) -> str:
        recommendation = tool_result.get("recommendation")
        if recommendation:
            courses = "、".join(item["name"] for item in recommendation.get("courses", [])) or "暂无匹配课程"
            papers = "、".join(item["name"] for item in recommendation.get("papers", [])) or "暂无匹配试卷"
            return f"{recommendation['explanation']}\n推荐课程：{courses}\n配套试卷：{papers}"
        return "我可以帮助分析学情、推荐课程和试卷。请先完善学生档案，或告诉我年级、科目、成绩、薄弱点和学习目标。"


class OpenAICompatibleModelClient(ModelClient):
    """Reserved provider seam. It is intentionally disabled until a real key is supplied."""

    async def compose(self, intent: str, tool_result: dict) -> str:
        raise RuntimeError("真实模型尚未启用，请设置 AI_PROVIDER 和 API Key")
