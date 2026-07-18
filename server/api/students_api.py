from secrets import token_hex

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import StudentProfile, StudentSubjectProfile, User
from server.schemas import StudentCreate, StudentUpdate
from server.services.access_service import ensure_student_access, get_user_family_id
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/students", tags=["students"])


async def serialize_student(db: AsyncSession, profile: StudentProfile) -> dict:
    subjects = list((await db.scalars(select(StudentSubjectProfile).where(
        StudentSubjectProfile.student_profile_id == profile.id
    ))).all())
    return {
        "id": profile.id, "name": profile.name, "grade": profile.grade,
        "learningGoal": profile.learning_goal, "weeklyStudyMinutes": profile.weekly_study_minutes,
        "bindCode": None if profile.bind_code_used else profile.bind_code,
        "studentUserId": profile.student_user_id,
        "subjects": [{"subject": item.subject, "recentScore": item.recent_score, "weakPoints": item.weak_points} for item in subjects],
    }


@router.post("")
async def create_student(payload: StudentCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="只有家长账号可以创建学生档案")
    family_id = await get_user_family_id(db, user.id)
    if family_id is None:
        raise HTTPException(status_code=400, detail="请先创建家庭")
    profile = StudentProfile(
        family_id=family_id, name=payload.name, grade=payload.grade, learning_goal=payload.learning_goal,
        weekly_study_minutes=payload.weekly_study_minutes, bind_code=f"STU-{token_hex(4).upper()}",
    )
    db.add(profile)
    await db.flush()
    db.add(StudentSubjectProfile(
        student_profile_id=profile.id, subject=payload.subject,
        recent_score=payload.recent_score, weak_points=payload.weak_points,
    ))
    await db.commit()
    return ok(await serialize_student(db, profile), "学生档案创建成功")


@router.get("/{student_id}")
async def get_student(student_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    profile = await ensure_student_access(db, user, student_id)
    return ok(await serialize_student(db, profile))


@router.put("/{student_id}")
async def update_student(student_id: int, payload: StudentUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    profile = await ensure_student_access(db, user, student_id)
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="只有家长账号可以修改学生档案")
    profile.name = payload.name
    profile.grade = payload.grade
    profile.learning_goal = payload.learning_goal
    profile.weekly_study_minutes = payload.weekly_study_minutes
    subject = await db.scalar(select(StudentSubjectProfile).where(
        StudentSubjectProfile.student_profile_id == profile.id,
        StudentSubjectProfile.subject == payload.subject,
    ))
    if subject is None:
        subject = StudentSubjectProfile(student_profile_id=profile.id, subject=payload.subject, recent_score=payload.recent_score, weak_points=payload.weak_points)
        db.add(subject)
    else:
        subject.recent_score = payload.recent_score
        subject.weak_points = payload.weak_points
    await db.commit()
    return ok(await serialize_student(db, profile), "学生档案已更新")
