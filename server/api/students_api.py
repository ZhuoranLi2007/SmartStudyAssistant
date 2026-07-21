from secrets import token_hex

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import StudentProfile, StudentSubjectProfile, User, WrongQuestion
from server.schemas import (
    StudentCreate, StudentUpdate, WrongQuestionBatchCreate,
    WrongQuestionMasteryUpdate, WrongQuestionTrainingSubmit,
)
from server.services.access_service import ensure_student_access, get_user_family_id
from server.services.learning_service import (
    add_wrong_questions_batch,
    learning_report,
    submit_wrong_question_training,
    wrong_question_list,
    wrong_question_training,
)
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/students", tags=["students"])


async def serialize_student(db: AsyncSession, profile: StudentProfile) -> dict:
    subjects = list((await db.scalars(select(StudentSubjectProfile).where(
        StudentSubjectProfile.student_profile_id == profile.id
    ).order_by(StudentSubjectProfile.updated_at.desc(), StudentSubjectProfile.id.desc()))).all())
    return {
        "id": profile.id, "name": profile.name, "grade": profile.grade,
        "learningGoal": profile.learning_goal, "weeklyStudyMinutes": profile.weekly_study_minutes,
        "bindCode": None if profile.bind_code_used else profile.bind_code,
        "studentUserId": profile.student_user_id,
        "profileCompleted": profile.profile_completed,
        "subjects": [{"subject": item.subject, "recentScore": item.recent_score, "weakPoints": item.weak_points} for item in subjects],
    }


@router.post("")
async def create_student(payload: StudentCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    family_id = await get_user_family_id(db, user.id)
    if family_id is None:
        raise HTTPException(status_code=400, detail="请先注册账号")
    profile = StudentProfile(
        family_id=family_id, name=payload.name, grade=payload.grade, learning_goal=payload.learning_goal,
        weekly_study_minutes=payload.weekly_study_minutes, bind_code=f"STU-{token_hex(4).upper()}",
        student_user_id=user.id, bind_code_used=True,
    )
    db.add(profile)
    await db.flush()
    db.add(StudentSubjectProfile(
        student_profile_id=profile.id, subject=payload.subject,
        recent_score=payload.recent_score, weak_points=payload.weak_points,
    ))
    await db.commit()
    return ok(await serialize_student(db, profile), "学习档案创建成功")


@router.get("/{student_id}")
async def get_student(student_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    profile = await ensure_student_access(db, user, student_id)
    return ok(await serialize_student(db, profile))


@router.put("/{student_id}")
async def update_student(student_id: int, payload: StudentUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    profile = await ensure_student_access(db, user, student_id)
    profile.name = payload.name
    profile.grade = payload.grade
    profile.learning_goal = payload.learning_goal
    profile.weekly_study_minutes = payload.weekly_study_minutes
    profile.profile_completed = True
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
    return ok(await serialize_student(db, profile), "学习档案已更新")


@router.get("/{student_id}/wrong-questions")
async def get_wrong_questions(
    student_id: int, subject: str | None = None,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    filtered = None if not subject or subject in ("全部", "all", "ALL") else subject
    return ok(await wrong_question_list(db, user, student_id, filtered))


@router.post("/{student_id}/wrong-questions/batch")
async def create_wrong_questions_batch(
    student_id: int, payload: WrongQuestionBatchCreate,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    result = await add_wrong_questions_batch(db, user, student_id, payload.items)
    await db.commit()
    return ok(result, f"已加入 {result['savedCount']} 道错题")


@router.put("/{student_id}/wrong-questions/{wrong_question_id}/mastered")
async def update_wrong_question(
    student_id: int, wrong_question_id: int, payload: WrongQuestionMasteryUpdate,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_id)
    row = await db.get(WrongQuestion, wrong_question_id)
    if row is None or row.student_profile_id != student_id:
        raise HTTPException(status_code=404, detail="错题不存在")
    row.mastered = payload.mastered
    await db.commit()
    return ok({"id": row.id, "mastered": row.mastered}, "错题状态已更新")


@router.delete("/{student_id}/wrong-questions/{wrong_question_id}")
async def delete_wrong_question(
    student_id: int, wrong_question_id: int,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_id)
    row = await db.get(WrongQuestion, wrong_question_id)
    if row is None or row.student_profile_id != student_id:
        raise HTTPException(status_code=404, detail="错题不存在")
    await db.delete(row)
    await db.commit()
    return ok({"id": wrong_question_id, "deleted": True}, "错题已删除")


@router.post("/{student_id}/wrong-questions/{wrong_question_id}/remove")
async def remove_wrong_question(
    student_id: int, wrong_question_id: int,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    """兼容部分客户端对 DELETE 支持不完整的情况。"""
    await ensure_student_access(db, user, student_id)
    row = await db.get(WrongQuestion, wrong_question_id)
    if row is None or row.student_profile_id != student_id:
        raise HTTPException(status_code=404, detail="错题不存在")
    await db.delete(row)
    await db.commit()
    return ok({"id": wrong_question_id, "deleted": True}, "错题已删除")


@router.get("/{student_id}/wrong-questions/{wrong_question_id}/training")
async def get_wrong_question_training(
    student_id: int, wrong_question_id: int,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    return ok(await wrong_question_training(db, user, student_id, wrong_question_id))


@router.post("/{student_id}/wrong-questions/{wrong_question_id}/training/submit")
async def submit_wrong_question_retest(
    student_id: int, wrong_question_id: int, payload: WrongQuestionTrainingSubmit,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    result = await submit_wrong_question_training(
        db, user, student_id, wrong_question_id, payload.selected_index
    )
    await db.commit()
    return ok(result, "复测完成")


@router.get("/{student_id}/learning-report")
async def get_learning_report(student_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return ok(await learning_report(db, user, student_id))
