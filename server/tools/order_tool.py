from server.services.order_service import create_pending_order, list_orders
from server.tools.base_tool import BusinessTool, ToolContext


class OrderTool(BusinessTool):
    name = "order_tool"
    description = "查询订单，或在用户明确确认后创建待支付课程订单"
    input_schema = {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["list", "create"]},
            "courseId": {"type": "integer", "minimum": 1},
            "orderStatus": {"type": "string", "enum": ["PENDING", "PAID", "CANCELLED"]},
        },
        "required": ["action"],
        "additionalProperties": False,
    }

    async def execute(self, context: ToolContext, arguments: dict) -> dict:
        action = str(arguments.get("action") or "list")
        if action == "list":
            return {"orders": await list_orders(context.db, context.user, arguments.get("orderStatus"))}
        if action != "create":
            raise ValueError("不支持的订单操作")
        course_id = arguments.get("courseId")
        if not isinstance(course_id, int):
            raise ValueError("创建订单需要有效 courseId")
        # 是否已经获得二次确认由 Agent 编排层依据服务端会话状态判断，模型参数不能充当授权。
        order, created = await create_pending_order(context.db, context.user, context.student.id, course_id)
        return {"order": order, "created": created}
