from sqlalchemy import select

from server.models import Course
from server.tools.base_tool import BusinessTool, ToolContext


class CourseSearchTool(BusinessTool):
    name = "course_search_tool"
    description = "按年级、学科、等级、知识点和价格检索真实课程"
    input_schema = {
        "type": "object",
        "properties": {
            "grade": {"type": "string"},
            "subject": {"type": "string", "enum": ["语文", "数学", "英语"]},
            "courseLevel": {"type": "string", "enum": ["基础巩固型", "中等提升型", "拔高拓展型"]},
            "knowledgePoint": {"type": "string"},
            "maxPrice": {"type": "number", "minimum": 0},
        },
        "additionalProperties": False,
    }

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        grade = arguments.get("grade") or context.student.grade
        subject = str(arguments.get("subject") or "")
        level = arguments.get("courseLevel")
        if level == "同步提高型":
            level = "中等提升型"
        max_price = arguments.get("maxPrice")
        point = str(arguments.get("knowledgePoint") or "")

        exact = select(Course).where(Course.is_active.is_(True))
        if grade:
            exact = exact.where(Course.grade == grade)
        if subject:
            exact = exact.where(Course.subject == subject)
        if level:
            exact = exact.where(Course.level == level)
        if max_price is not None:
            exact = exact.where(Course.price <= float(max_price))
        rows = list((await context.db.scalars(exact.order_by(Course.id))).all())
        if point:
            rows = [row for row in rows if point in (row.knowledge_points or [])]

        # 精确条件没有资源时逐步放宽，但用户明确指定的学科始终保留。
        if not rows:
            same_grade = select(Course).where(Course.is_active.is_(True))
            if grade:
                same_grade = same_grade.where(Course.grade == grade)
            if subject:
                same_grade = same_grade.where(Course.subject == subject)
            if max_price is not None:
                same_grade = same_grade.where(Course.price <= float(max_price))
            rows = list((await context.db.scalars(same_grade.order_by(Course.id))).all())
        if not rows and subject:
            rows = list((await context.db.scalars(select(Course).where(
                Course.is_active.is_(True),
                Course.subject == subject,
            ).order_by(Course.id))).all())
        rows = sorted(rows, key=lambda row: (
            bool(point) and point not in (row.knowledge_points or []),
            bool(level) and row.level != level,
            row.id,
        ))

        return {"courses": [{
            "id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "level": row.level, "difficulty": row.difficulty, "price": float(row.price),
            "totalLessons": row.total_lessons, "knowledgePoints": row.knowledge_points,
            "suitableFor": row.suitable_for, "description": row.description,
        } for row in rows[:8]]}
