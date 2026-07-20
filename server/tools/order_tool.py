from server.services.order_service import create_pending_order, list_orders
from server.tools.base_tool import BusinessTool, ToolContext


class OrderTool(BusinessTool):
    name = "order_tool"
    description = "查询订单，或在用户明确确认后创建待支付课程订单"
    input_schema = {"type": "object", "properties": {"action": {}, "courseId": {}, "confirmed": {}, "orderStatus": {}}}

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        action = str(arguments.get("action") or "list")
        if action == "list":
            return {"orders": await list_orders(context.db, context.user, arguments.get("orderStatus"))}
        if action != "create" or not arguments.get("confirmed"):
            return {"confirmationRequired": True, "message": "请明确回复“确认报名”后再创建待支付订单。"}
        course_id = arguments.get("courseId")
        if not isinstance(course_id, int):
            raise ValueError("创建订单需要有效 courseId")
        order, created = await create_pending_order(context.db, context.user, context.student.id, course_id)
        return {"order": order, "created": created}
