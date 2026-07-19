from sqlalchemy import select

from server.models import Paper
from server.tools.base_tool import BusinessTool, ToolContext


class PaperSearchTool(BusinessTool):
    name = "paper_search_tool"
    description = "按年级、学科、难度和知识点检索真实试卷"
    input_schema = {"type": "object", "properties": {"grade": {}, "subject": {}, "difficulty": {}, "knowledgePoint": {}}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        statement = select(Paper).where(Paper.is_active.is_(True))
        for field in ("grade", "subject", "difficulty"):
            if arguments.get(field):
                statement = statement.where(getattr(Paper, field) == arguments[field])
        rows = list((await context.db.scalars(statement.order_by(Paper.id).limit(8))).all())
        point = str(arguments.get("knowledgePoint") or "")
        if point:
            rows = [row for row in rows if point in (row.knowledge_points or [])]
        return {"papers": [{
            "id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "difficulty": row.difficulty, "questionCount": row.question_count,
            "knowledgePoints": row.knowledge_points,
        } for row in rows]}
