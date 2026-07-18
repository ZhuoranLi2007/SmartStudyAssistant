from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Course, Paper, StudyTask, User
from server.schemas import StudyTaskCreate, TaskStatusUpdate
from server.services.access_service import ensure_student_access
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/study-plans", tags=["study-plans"])


def task_data(row: StudyTask) -> dict:
    return {"id": row.id, "studentProfileId": row.student_profile_id, "name": row.name, "taskType": row.task_type,
            "subject": row.subject, "difficulty": row.difficulty, "status": row.status,
            "createdAt": row.created_at.isoformat()}


@router.get("")
async def list_tasks(
    student_profile_id: int = Query(...), db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_profile_id)
    rows = list((await db.scalars(select(StudyTask).where(
        StudyTask.student_profile_id == student_profile_id
    ).order_by(StudyTask.created_at.desc()))).all())
    return ok([task_data(row) for row in rows])


@router.post("")
async def add_task(payload: StudyTaskCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await ensure_student_access(db, user, payload.student_profile_id)
    target = await db.get(Course if payload.task_type == "课程" else Paper, payload.target_id)
    if target is None: raise HTTPException(status_code=404, detail="课程或试卷不存在")
    row = StudyTask(student_profile_id=payload.student_profile_id, creator_user_id=user.id,
                    task_type=payload.task_type, target_id=payload.target_id, name=target.name,
                    subject=target.subject, difficulty=target.difficulty)
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return ok(task_data(row), "已加入学习计划")


@router.put("/{task_id}/status")
async def update_status(task_id: int, payload: TaskStatusUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    row = await db.get(StudyTask, task_id)
    if row is None: raise HTTPException(status_code=404, detail="学习任务不存在")
    await ensure_student_access(db, user, row.student_profile_id)
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
