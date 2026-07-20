from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Course, Paper, StudentSubjectProfile, StudyTask, User, WrongQuestion
from server.schemas import StudyTaskCreate, TaskStatusUpdate
from server.services.access_service import ensure_student_access
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/study-plans", tags=["study-plans"])


def task_data(row: StudyTask) -> dict:
    return {
        "id": row.id,
        "studentProfileId": row.student_profile_id,
        "targetId": row.target_id,
        "name": row.name,
        "taskType": row.task_type,
        "subject": row.subject,
        "difficulty": row.difficulty,
        "status": row.status,
        "scheduledDate": row.scheduled_date.isoformat() if row.scheduled_date else "",
        "durationMinutes": row.duration_minutes,
        "knowledgePoint": row.knowledge_point,
        "sourceSessionId": row.source_session_id or "",
        "createdAt": row.created_at.isoformat(),
    }


async def next_available_date(db: AsyncSession, student_profile_id: int) -> date:
    today = date.today()
    week_end = today + timedelta(days=6 - today.weekday())
    rows = list((await db.scalars(select(StudyTask).where(
        StudyTask.student_profile_id == student_profile_id,
        StudyTask.scheduled_date >= today,
        StudyTask.scheduled_date <= week_end,
    ))).all())
    counts: dict[date, int] = {}
    current = today
    while current <= week_end:
        counts[current] = 0
        current += timedelta(days=1)
    for row in rows:
        if row.scheduled_date in counts:
            counts[row.scheduled_date] += 1
    return min(counts, key=lambda item: (counts[item], item))


@router.get("")
async def list_tasks(
    student_profile_id: int = Query(...), db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_profile_id)
    rows = list((await db.scalars(select(StudyTask).where(
        StudyTask.student_profile_id == student_profile_id
    ).order_by(StudyTask.scheduled_date, StudyTask.created_at))).all())
    return ok([task_data(row) for row in rows])


@router.get("/recommended-papers")
async def recommended_papers(
    student_profile_id: int = Query(...), limit: int = Query(3, ge=1, le=6),
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    profile = await ensure_student_access(db, user, student_profile_id)
    subject_profile = await db.scalar(select(StudentSubjectProfile).where(
        StudentSubjectProfile.student_profile_id == student_profile_id,
    ).order_by(StudentSubjectProfile.id))
    statement = select(Paper).where(Paper.is_active.is_(True), Paper.grade == profile.grade)
    if subject_profile is not None:
        statement = statement.where(Paper.subject == subject_profile.subject)
    papers = list((await db.scalars(statement.order_by(Paper.id))).all())
    planned_ids = set((await db.scalars(select(StudyTask.target_id).where(
        StudyTask.student_profile_id == student_profile_id,
        StudyTask.task_type == "试卷",
    ))).all())
    papers = [paper for paper in papers if paper.id not in planned_ids]
    weak_points = subject_profile.weak_points if subject_profile is not None else []
    papers.sort(key=lambda paper: (
        -len(set(paper.knowledge_points or []).intersection(weak_points)), paper.id
    ))
    result = []
    for paper in papers[:limit]:
        matched = [point for point in (paper.knowledge_points or []) if point in weak_points]
        reason = f"针对薄弱知识点{'、'.join(matched)}进行专项巩固" if matched else f"适合{profile.grade}{paper.subject}阶段训练"
        result.append({
            "id": paper.id,
            "name": paper.name,
            "grade": paper.grade,
            "subject": paper.subject,
            "difficulty": paper.difficulty,
            "knowledgePoints": paper.knowledge_points,
            "questionCount": paper.question_count,
            "recommendReason": reason,
        })
    return ok(result)


@router.get("/recommended-wrong-questions")
async def recommended_wrong_questions(
    student_profile_id: int = Query(...), limit: int = Query(4, ge=1, le=10),
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_profile_id)
    planned_ids = set((await db.scalars(select(StudyTask.target_id).where(
        StudyTask.student_profile_id == student_profile_id,
        StudyTask.task_type == "错题",
        StudyTask.status != "已完成",
    ))).all())
    rows = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
        WrongQuestion.mastered.is_(False),
    ).order_by(WrongQuestion.wrong_count.desc(), WrongQuestion.updated_at.desc()))).all())
    result = []
    for row in rows:
        if row.id in planned_ids:
            continue
        result.append({
            "id": row.id,
            "subject": row.subject,
            "knowledgePoint": row.knowledge_point,
            "question": row.question_text,
            "wrongCount": row.wrong_count,
            "recommendReason": f"该题已答错{row.wrong_count}次，建议通过原题复测巩固{row.knowledge_point}",
        })
        if len(result) >= limit:
            break
    return ok(result)


@router.post("")
async def add_task(payload: StudyTaskCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await ensure_student_access(db, user, payload.student_profile_id)
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="只有家长可以安排学习任务")
    if payload.task_type == "课程":
        target = await db.get(Course, payload.target_id)
    elif payload.task_type == "试卷":
        target = await db.get(Paper, payload.target_id)
    else:
        target = await db.get(WrongQuestion, payload.target_id)
        if target is not None and target.student_profile_id != payload.student_profile_id:
            target = None
        if target is not None and target.mastered:
            raise HTTPException(status_code=409, detail="该错题已经掌握，无需重复安排")
    if target is None:
        raise HTTPException(status_code=404, detail="课程、试卷或错题不存在")
    duplicate = await db.scalar(select(StudyTask).where(
        StudyTask.student_profile_id == payload.student_profile_id,
        StudyTask.task_type == payload.task_type,
        StudyTask.target_id == payload.target_id,
    ))
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="该学习内容已在学习计划中")
    scheduled_date = await next_available_date(db, payload.student_profile_id)
    if payload.task_type == "错题":
        name = f"{target.knowledge_point}错题复测"
        subject = target.subject
        difficulty = "错题巩固"
        duration_minutes = 15
        knowledge_point = target.knowledge_point
    else:
        knowledge_points = target.knowledge_points or []
        name = target.name
        subject = target.subject
        difficulty = target.difficulty
        duration_minutes = 40
        knowledge_point = knowledge_points[0] if knowledge_points else "综合训练"
    row = StudyTask(student_profile_id=payload.student_profile_id, creator_user_id=user.id,
                    task_type=payload.task_type, target_id=payload.target_id, name=name,
                    subject=subject, difficulty=difficulty,
                    scheduled_date=scheduled_date, duration_minutes=duration_minutes,
                    knowledge_point=knowledge_point)
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return ok(task_data(row), "已加入学习计划")


@router.put("/{task_id}/status")
async def update_status(task_id: int, payload: TaskStatusUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    row = await db.get(StudyTask, task_id)
    if row is None: raise HTTPException(status_code=404, detail="学习任务不存在")
    await ensure_student_access(db, user, row.student_profile_id)
    if user.role != "student":
        raise HTTPException(status_code=403, detail="学习任务状态由学生账号更新")
    row.status = payload.status
    await db.commit()
    return ok(task_data(row), "任务状态已更新")


@router.delete("/{task_id}")
async def delete_task(task_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    row = await db.get(StudyTask, task_id)
    if row is None: raise HTTPException(status_code=404, detail="学习任务不存在")
    await ensure_student_access(db, user, row.student_profile_id)
    if user.role != "parent": raise HTTPException(status_code=403, detail="只有家长可以删除学习任务")
    await db.delete(row)
    await db.commit()
    return ok(None, "学习任务已删除")
