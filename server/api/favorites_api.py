from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Course, Favorite, Paper, User
from server.services.access_service import ensure_student_access
from server.services.ai_paper_service import _display_name
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/favorites", tags=["favorites"])


def normalize_type(value: str) -> str:
    lowered = (value or "").strip().lower()
    if lowered in ("course", "paper"):
        return lowered
    raise HTTPException(status_code=422, detail="收藏类型仅支持 course 或 paper")


def favorite_data(row: Favorite, course: Course | None = None, paper: Paper | None = None) -> dict:
    grade = ""
    subject = ""
    level = row.tag or ""
    if course is not None:
        grade = course.grade
        subject = course.subject
        level = course.level
    elif paper is not None:
        grade = paper.grade
        subject = paper.subject
        level = paper.difficulty
    return {
        "id": row.id,
        "favoriteId": row.id,
        "targetId": row.target_id,
        "type": (row.type or "").upper(),
        "title": _display_name(row.title) if row.type == "paper" else row.title,
        "subtitle": row.subtitle or "",
        "tag": row.tag or "",
        "grade": grade,
        "subject": subject,
        "level": level,
        "coverKey": "",
        "createdAt": row.created_at.isoformat() if row.created_at else "",
    }


@router.get("")
async def list_favorites(
    student_profile_id: int = Query(...),
    type: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_profile_id)
    statement = select(Favorite).where(Favorite.student_profile_id == student_profile_id)
    if type:
        statement = statement.where(Favorite.type == normalize_type(type))
    rows = list((await db.scalars(statement.order_by(Favorite.created_at.desc()))).all())
    result = []
    for row in rows:
        course = await db.get(Course, row.target_id) if row.type == "course" else None
        paper = await db.get(Paper, row.target_id) if row.type == "paper" else None
        result.append(favorite_data(row, course, paper))
    return ok(result)


@router.post("")
async def add_favorite(
    student_profile_id: int = Query(...),
    target_id: int = Query(...),
    type: str = Query(...),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await ensure_student_access(db, user, student_profile_id)
    favorite_type = normalize_type(type)
    existing = await db.scalar(select(Favorite).where(
        Favorite.student_profile_id == student_profile_id,
        Favorite.target_id == target_id,
        Favorite.type == favorite_type,
    ))
    if existing is not None:
        course = await db.get(Course, existing.target_id) if existing.type == "course" else None
        paper = await db.get(Paper, existing.target_id) if existing.type == "paper" else None
        return ok(favorite_data(existing, course, paper), "已经收藏过了")
    if favorite_type == "course":
        target = await db.get(Course, target_id)
        if target is None:
            raise HTTPException(status_code=404, detail="课程不存在")
        title = target.name
        subtitle = f"{target.grade} · {target.subject}"
        tag = target.level
        course, paper = target, None
    else:
        target = await db.get(Paper, target_id)
        if target is None:
            raise HTTPException(status_code=404, detail="试卷不存在")
        title = _display_name(target.name) if target.is_ai_generated else target.name
        subtitle = f"{target.question_count}题 · {target.difficulty}"
        tag = target.subject
        course, paper = None, target
    row = Favorite(
        student_profile_id=student_profile_id,
        target_id=target_id,
        type=favorite_type,
        title=title,
        subtitle=subtitle,
        tag=tag,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return ok(favorite_data(row, course, paper), "收藏成功")


@router.delete("/{favorite_id}")
async def remove_favorite(
    favorite_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    row = await db.get(Favorite, favorite_id)
    if row is None:
        raise HTTPException(status_code=404, detail="收藏不存在")
    await ensure_student_access(db, user, row.student_profile_id)
    await db.delete(row)
    await db.commit()
    return ok(None, "已取消收藏")
