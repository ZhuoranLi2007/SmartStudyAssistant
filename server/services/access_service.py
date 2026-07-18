from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import FamilyMember, StudentProfile, User


async def get_user_family_id(db: AsyncSession, user_id: int) -> int | None:
    return await db.scalar(select(FamilyMember.family_id).where(FamilyMember.user_id == user_id))


async def ensure_student_access(db: AsyncSession, user: User, student_profile_id: int) -> StudentProfile:
    profile = await db.get(StudentProfile, student_profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="学生档案不存在")
    family_id = await get_user_family_id(db, user.id)
    if family_id != profile.family_id:
        raise HTTPException(status_code=403, detail="无权访问其他家庭的学生档案")
    if user.role == "student" and profile.student_user_id != user.id:
        raise HTTPException(status_code=403, detail="学生账号只能访问自己的档案")
    return profile
