from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Course, User
from server.schemas import RecommendationRequest
from server.services.access_service import ensure_student_access
from server.services.learning_service import my_courses
from server.services.recommendation_service import recommend_for_student
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/courses", tags=["courses"])


def course_data(row: Course) -> dict:
    return {"id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject, "level": row.level,
            "difficulty": row.difficulty, "suitableFor": row.suitable_for, "knowledgePoints": row.knowledge_points,
            "description": row.description, "price": float(row.price), "totalLessons": row.total_lessons}


@router.get("")
async def list_courses(
    grade: str | None = Query(None), subject: str | None = Query(None), level: str | None = Query(None),
    db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user),
):
    statement = select(Course).where(Course.is_active.is_(True))
    if grade: statement = statement.where(Course.grade == grade)
    if subject: statement = statement.where(Course.subject == subject)
    if level: statement = statement.where(Course.level == level)
    rows = list((await db.scalars(statement.order_by(Course.id))).all())
    return ok([course_data(row) for row in rows])


@router.get("/my")
async def get_my_courses(
    student_profile_id: int | None = Query(None),
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    return ok(await my_courses(db, user, student_profile_id))


@router.get("/{course_id}")
async def get_course(course_id: int, db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user)):
    row = await db.get(Course, course_id)
    if row is None: raise HTTPException(status_code=404, detail="课程不存在")
    return ok(course_data(row))


@router.post("/recommend")
async def recommend(payload: RecommendationRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    profile = await ensure_student_access(db, user, payload.student_profile_id)
    result = await recommend_for_student(db, user, profile, payload.subject)
    await db.commit()
    return ok(result)
