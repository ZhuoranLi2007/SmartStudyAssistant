from server.services.recommendation_service import recommend_for_student
from server.tools.base_tool import BusinessTool, ToolContext


class CourseRecommendTool(BusinessTool):
    name = "course_recommend_tool"
    description = "根据真实学生档案和课程目录执行可解释的分层推荐"
    input_schema = {"type": "object", "properties": {"subject": {"type": "string"}}, "required": ["subject"]}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        return await recommend_for_student(
            context.db, context.user, context.student, str(arguments["subject"]), context.session_id
        )
