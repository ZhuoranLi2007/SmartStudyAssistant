from secrets import token_hex

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Family, FamilyMember, StudentProfile, User
from server.schemas import BindStudentRequest, FamilyCreate
from server.services.access_service import get_user_family_id
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/families", tags=["families"])


@router.post("")
async def create_family(payload: FamilyCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="只有家长账号可以创建家庭")
    if await get_user_family_id(db, user.id):
        raise HTTPException(status_code=409, detail="当前账号已经加入家庭")
    family = Family(name=payload.name, created_by=user.id, invite_code=f"FAM-{token_hex(4).upper()}")
    db.add(family)
    await db.flush()
    db.add(FamilyMember(family_id=family.id, user_id=user.id, family_role="parent"))
    await db.commit()
    return ok({"id": family.id, "name": family.name, "inviteCode": family.invite_code}, "家庭创建成功")


@router.get("/current")
async def current_family(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    family_id = await get_user_family_id(db, user.id)
    if family_id is None:
        return ok(None, "当前账号尚未加入家庭")
    family = await db.get(Family, family_id)
    return ok({"id": family.id, "name": family.name, "inviteCode": family.invite_code})


@router.post("/bind-student")
async def bind_student(payload: BindStudentRequest, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role != "student":
        raise HTTPException(status_code=403, detail="只有学生账号可以使用学生绑定码")
    if await get_user_family_id(db, user.id):
        raise HTTPException(status_code=409, detail="当前学生已经绑定家庭")
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.bind_code == payload.bind_code))
    if profile is None or profile.bind_code_used:
        raise HTTPException(status_code=404, detail="绑定码不存在或已经使用")
    profile.student_user_id = user.id
    profile.bind_code_used = True
    db.add(FamilyMember(family_id=profile.family_id, user_id=user.id, family_role="student"))
    await db.commit()
    return ok({"studentProfileId": profile.id, "familyId": profile.family_id}, "家庭绑定成功")
