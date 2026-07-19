from sqlalchemy import select

from server.models import Course
from server.tools.base_tool import BusinessTool, ToolContext


class CourseSearchTool(BusinessTool):
    name = "course_search_tool"
    description = "按年级、学科、等级、知识点和价格检索真实课程"
    input_schema = {"type": "object", "properties": {"grade": {}, "subject": {}, "courseLevel": {}, "knowledgePoint": {}, "maxPrice": {}}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        statement = select(Course).where(Course.is_active.is_(True))
        if arguments.get("grade"):
            statement = statement.where(Course.grade == arguments["grade"])
        if arguments.get("subject"):
            statement = statement.where(Course.subject == arguments["subject"])
        if arguments.get("courseLevel"):
            level = "中等提升型" if arguments["courseLevel"] == "同步提高型" else arguments["courseLevel"]
            statement = statement.where(Course.level == level)
        if arguments.get("maxPrice") is not None:
            statement = statement.where(Course.price <= float(arguments["maxPrice"]))
        rows = list((await context.db.scalars(statement.order_by(Course.id).limit(8))).all())
        point = str(arguments.get("knowledgePoint") or "")
        if point:
            rows = [row for row in rows if point in (row.knowledge_points or [])]
        return {"courses": [{
            "id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "level": row.level, "difficulty": row.difficulty, "price": float(row.price),
            "knowledgePoints": row.knowledge_points,
        } for row in rows]}
