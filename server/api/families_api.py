from datetime import date, timedelta
from secrets import token_hex

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import (
    CourseEnrollment,
    Family,
    FamilyMember,
    Favorite,
    StudentProfile,
    StudyTask,
    User,
    WrongQuestion,
)
from server.schemas import BindStudentRequest, FamilyCreate
from server.services.access_service import get_user_family_id
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/families", tags=["families"])


async def build_profile_overview(db: AsyncSession, family: Family, user: User) -> dict:
    profile = await db.scalar(
        select(StudentProfile).where(StudentProfile.student_user_id == user.id)
    )
    if profile is None:
        profile = await db.scalar(
            select(StudentProfile).where(StudentProfile.family_id == family.id).order_by(StudentProfile.id)
        )

    course_count = 0
    weekly_task_count = 0
    favorite_count = 0
    wrong_question_count = 0
    student_name = ""
    student_bound = False

    if profile is not None:
        student_name = profile.name
        student_bound = True
        course_count = int(await db.scalar(
            select(func.count()).select_from(CourseEnrollment).where(
                CourseEnrollment.student_profile_id == profile.id
            )
        ) or 0)
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
        week_end = week_start + timedelta(days=6)
        weekly_task_count = int(await db.scalar(
            select(func.count()).select_from(StudyTask).where(
                StudyTask.student_profile_id == profile.id,
                StudyTask.scheduled_date >= week_start,
                StudyTask.scheduled_date <= week_end,
            )
        ) or 0)
        favorite_count = int(await db.scalar(
            select(func.count()).select_from(Favorite).where(Favorite.student_profile_id == profile.id)
        ) or 0)
        wrong_question_count = int(await db.scalar(
            select(func.count()).select_from(WrongQuestion).where(
                WrongQuestion.student_profile_id == profile.id,
                WrongQuestion.mastered.is_(False),
            )
        ) or 0)

    return {
        "id": family.id,
        "name": family.name,
        "inviteCode": family.invite_code,
        "familyCode": family.invite_code,
        "studentBindCode": "",
        "studentName": student_name,
        "studentBound": student_bound,
        "studentProfileId": profile.id if profile is not None else 0,
        "learning": {
            "courseCount": course_count,
            "weeklyTaskCount": weekly_task_count,
            "favoriteCount": favorite_count,
            "wrongQuestionCount": wrong_question_count,
        },
    }


@router.post("")
async def create_family(payload: FamilyCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if await get_user_family_id(db, user.id):
        raise HTTPException(status_code=409, detail="当前账号已有学习空间")
    family = Family(name=payload.name, created_by=user.id, invite_code=f"FAM-{token_hex(4).upper()}")
    db.add(family)
    await db.flush()
    db.add(FamilyMember(family_id=family.id, user_id=user.id, family_role="owner"))
    await db.commit()
    return ok({"id": family.id, "name": family.name, "inviteCode": family.invite_code}, "学习空间创建成功")


@router.get("/current")
async def current_family(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    family_id = await get_user_family_id(db, user.id)
    if family_id is None:
        return ok(None, "当前账号尚未创建学习空间")
    family = await db.get(Family, family_id)
    if family is None:
        return ok(None, "学习空间不存在")
    return ok(await build_profile_overview(db, family, user))


@router.post("/bind-student")
async def bind_student(payload: BindStudentRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    # 兼容旧接口：统一账号下不再需要绑定
    return ok({"studentProfileId": 0, "familyId": 0}, "当前版本无需绑定")
