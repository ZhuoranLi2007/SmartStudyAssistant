from server.services.learning_service import learning_report
from server.tools.base_tool import BusinessTool, ToolContext


class LearningReportTool(BusinessTool):
    name = "learning_report_tool"
    description = "从课程、任务、练习和错题记录汇总学习报告"
    input_schema = {"type": "object", "properties": {}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        return {"learningReport": await learning_report(context.db, context.user, context.student.id)}
