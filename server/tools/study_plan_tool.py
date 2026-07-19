from server.services.learning_service import generate_week_plan
from server.tools.base_tool import BusinessTool, ToolContext


class StudyPlanTool(BusinessTool):
    name = "study_plan_tool"
    description = "根据学生时间和真实课程试卷生成七天学习计划"
    input_schema = {"type": "object", "properties": {}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        return {"studyPlan": await generate_week_plan(
            context.db, context.user, context.student.id, context.session_id
        )}
