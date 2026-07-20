from server.services.learning_service import wrong_question_list
from server.tools.base_tool import BusinessTool, ToolContext


class WrongQuestionTool(BusinessTool):
    name = "wrong_question_tool"
    description = "查询真实错题并统计高频薄弱知识点"
    input_schema = {"type": "object", "properties": {"subject": {"type": "string"}}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        rows = await wrong_question_list(context.db, context.user, context.student.id, arguments.get("subject"))
        counts: dict[str, int] = {}
        for row in rows:
            counts[row["knowledgePoint"]] = counts.get(row["knowledgePoint"], 0) + row["wrongCount"]
        return {"wrongQuestions": rows[:10], "frequentKnowledgePoints": sorted(counts, key=lambda key: counts[key], reverse=True)[:3]}
