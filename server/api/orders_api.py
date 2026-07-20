from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import User
from server.schemas import OrderCreate
from server.services.order_service import create_pending_order, get_order, list_orders, order_data, pay_order
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("")
async def orders(status: str | None = None, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return ok(await list_orders(db, user, status))


@router.post("")
async def create_order(payload: OrderCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    order, created = await create_pending_order(db, user, payload.student_profile_id, payload.course_id)
    await db.commit()
    return ok({"order": order, "created": created}, "待支付订单已创建" if created else "已存在待处理订单")


@router.get("/{order_id}")
async def order_detail(order_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    order, course = await get_order(db, user, order_id)
    return ok(order_data(order, course))


@router.post("/{order_id}/pay")
async def pay(order_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await pay_order(db, user, order_id)
    await db.commit()
    return ok(result, "模拟支付成功")
