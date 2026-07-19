from datetime import datetime, timezone
from decimal import Decimal
from secrets import token_hex

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, CourseEnrollment, CourseOrder, User
from server.services.access_service import ensure_student_access


def order_data(order: CourseOrder, course: Course | None = None) -> dict:
    return {
        "id": order.id,
        "orderNo": order.order_no,
        "courseId": order.course_id,
        "courseName": course.name if course else "",
        "studentProfileId": order.student_profile_id,
        "amount": float(order.amount),
        "createTime": order.created_at.isoformat() if order.created_at else "",
        "status": order.status,
    }


async def list_orders(db: AsyncSession, user: User, status: str | None = None) -> list[dict]:
    statement = select(CourseOrder, Course).join(Course, Course.id == CourseOrder.course_id).where(CourseOrder.user_id == user.id)
    if status:
        statement = statement.where(CourseOrder.status == status)
    rows = (await db.execute(statement.order_by(CourseOrder.created_at.desc()))).all()
    return [order_data(order, course) for order, course in rows]


async def get_order(db: AsyncSession, user: User, order_id: int) -> tuple[CourseOrder, Course]:
    row = (await db.execute(
        select(CourseOrder, Course).join(Course, Course.id == CourseOrder.course_id).where(CourseOrder.id == order_id)
    )).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="订单不存在")
    order, course = row
    await ensure_student_access(db, user, order.student_profile_id)
    if order.user_id != user.id and user.role != "parent":
        raise HTTPException(status_code=403, detail="无权访问该订单")
    return order, course


async def create_pending_order(db: AsyncSession, user: User, student_profile_id: int, course_id: int) -> tuple[dict, bool]:
    await ensure_student_access(db, user, student_profile_id)
    course = await db.get(Course, course_id)
    if course is None or not course.is_active:
        raise HTTPException(status_code=404, detail="课程不存在")
    existing = await db.scalar(select(CourseOrder).where(
        CourseOrder.student_profile_id == student_profile_id,
        CourseOrder.course_id == course_id,
        CourseOrder.status.in_(("PENDING", "PAID")),
    ).order_by(CourseOrder.id.desc()))
    if existing:
        return order_data(existing, course), False
    order = CourseOrder(
        order_no=f"SS{datetime.now(timezone.utc):%Y%m%d%H%M%S}{token_hex(2).upper()}",
        user_id=user.id,
        student_profile_id=student_profile_id,
        course_id=course_id,
        amount=Decimal(course.price),
        status="PENDING",
    )
    db.add(order)
    await db.flush()
    return order_data(order, course), True


async def pay_order(db: AsyncSession, user: User, order_id: int) -> dict:
    order, course = await get_order(db, user, order_id)
    if order.status == "CANCELLED":
        raise HTTPException(status_code=409, detail="已取消订单不能支付")
    if order.status == "PENDING":
        order.status = "PAID"
        order.paid_at = datetime.now(timezone.utc)
        enrollment = await db.scalar(select(CourseEnrollment).where(
            CourseEnrollment.student_profile_id == order.student_profile_id,
            CourseEnrollment.course_id == order.course_id,
        ))
        if enrollment is None:
            db.add(CourseEnrollment(
                student_profile_id=order.student_profile_id,
                course_id=order.course_id,
                order_id=order.id,
                total_lessons=course.total_lessons,
                next_lesson="第一课：课程导学",
            ))
    await db.flush()
    return order_data(order, course)
