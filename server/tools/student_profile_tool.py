from sqlalchemy import select

from server.models import StudentSubjectProfile
from server.tools.base_tool import BusinessTool, ToolContext


class StudentProfileTool(BusinessTool):
    name = "student_profile_tool"
    description = "读取已授权学生的年级、成绩、薄弱点、目标和学习时间"
    input_schema = {"type": "object", "properties": {"subject": {"type": "string"}}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        statement = select(StudentSubjectProfile).where(StudentSubjectProfile.student_profile_id == context.student.id)
        if arguments.get("subject"):
            statement = statement.where(StudentSubjectProfile.subject == arguments["subject"])
        subjects = list((await context.db.scalars(statement)).all())
        return {
            "studentId": context.student.id,
            "name": context.student.name,
            "grade": context.student.grade,
            "learningGoal": context.student.learning_goal,
            "weeklyHours": round(context.student.weekly_study_minutes / 60, 1),
            "subjects": [{"subject": item.subject, "score": item.recent_score, "weakPoints": item.weak_points} for item in subjects],
        }
