from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import FamilyMember, Paper, StudentProfile, User


async def get_user_family_id(db: AsyncSession, user_id: int) -> int | None:
    return await db.scalar(select(FamilyMember.family_id).where(FamilyMember.user_id == user_id))


async def ensure_student_access(db: AsyncSession, user: User, student_profile_id: int) -> StudentProfile:
    profile = await db.get(StudentProfile, student_profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="学习档案不存在")
    family_id = await get_user_family_id(db, user.id)
    if family_id != profile.family_id:
        raise HTTPException(status_code=403, detail="无权访问该学习档案")
    return profile


async def ensure_paper_access(db: AsyncSession, user: User, paper_id: int) -> Paper:
    paper = await db.get(Paper, paper_id)
    if paper is None or not paper.is_active:
        raise HTTPException(status_code=404, detail="试卷不存在")
    if paper.is_ai_generated and paper.created_by != user.id:
        raise HTTPException(status_code=403, detail="无权访问该 AI 试卷")
    return paper
