from sqlalchemy import select

from server.models import Paper, StudentSubjectProfile
from server.services.recommendation_service import calculate_level
from server.tools.base_tool import BusinessTool, ToolContext


_DIFFICULTY_TO_LEVEL = {"基础": "基础巩固型", "中等": "中等提升型", "较难": "拔高拓展型"}


class PaperSearchTool(BusinessTool):
    name = "paper_search_tool"
    description = "按学生档案的年级、学科、成绩层次和薄弱知识点检索真实试卷"
    input_schema = {"type": "object", "properties": {"grade": {}, "subject": {}, "difficulty": {}, "knowledgePoint": {}}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        subject = arguments.get("subject") or "数学"
        subject_profile = await context.db.scalar(select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == context.student.id,
            StudentSubjectProfile.subject == subject,
        ))
        if subject_profile is None:
            subject_profile = await context.db.scalar(select(StudentSubjectProfile).where(
                StudentSubjectProfile.student_profile_id == context.student.id
            ))

        grade = arguments.get("grade") or context.student.grade
        if subject_profile is not None:
            subject = subject_profile.subject

        # 若用户没有显式指定层次，则根据档案分数自动计算
        level = arguments.get("difficulty")
        if level:
            level = _DIFFICULTY_TO_LEVEL.get(level, level)
        elif subject_profile is not None:
            level = calculate_level(subject_profile.recent_score)

        statement = select(Paper).where(Paper.is_active.is_(True))
        if grade:
            statement = statement.where(Paper.grade == grade)
        if subject:
            statement = statement.where(Paper.subject == subject)
        if level:
            statement = statement.where(Paper.suitable_course_level == level)

        rows = list((await context.db.scalars(statement.order_by(Paper.id))).all())

        # 优先按薄弱知识点匹配
        weak_points = subject_profile.weak_points if subject_profile is not None else []
        knowledge_point = arguments.get("knowledgePoint")
        target_points = [knowledge_point] if knowledge_point else weak_points
        if target_points:
            matched = []
            for point in target_points:
                for row in rows:
                    if point in (row.knowledge_points or []) and row not in matched:
                        matched.append(row)
                        break
            rows = matched if matched else rows

        return {"papers": [{
            "id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "difficulty": row.difficulty, "questionCount": row.question_count,
            "knowledgePoints": row.knowledge_points,
        } for row in rows[:8]]}
