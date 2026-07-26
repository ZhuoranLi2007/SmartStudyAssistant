from server.ai.rag import RAGService
from server.tools.base_tool import BusinessTool, ToolContext


class KnowledgeSearchTool(BusinessTool):
    name = "knowledge_search_tool"
    description = "检索与当前学生年级、学科匹配的课程、试卷和学习知识资料；用于回答知识点、学习方法和资源依据问题"
    input_schema = {
        "type": "object",
        "properties": {
            "query": {"type": "string"},
            "subject": {"type": "string", "enum": ["语文", "数学", "英语"]},
            "sourceTypes": {
                "type": "array",
                "items": {"type": "string", "enum": ["course", "paper", "knowledge"]},
            },
            "topK": {"type": "integer", "minimum": 1, "maximum": 6},
        },
        "required": ["query"],
        "additionalProperties": False,
    }

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        rows = await RAGService(context.db).search(
            str(arguments["query"]),
            int(arguments.get("topK") or 4),
            grade=context.student.grade,
            subject=arguments.get("subject"),
            source_types=arguments.get("sourceTypes"),
        )
        return {"sources": rows}
