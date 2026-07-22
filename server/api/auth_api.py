from secrets import token_hex

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Family, FamilyMember, StudentProfile, StudentSubjectProfile, User
from server.schemas import LoginRequest, RegisterRequest
from server.utils.responses import ok
from server.utils.security import create_access_token, get_current_user, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def user_data(user: User) -> dict:
    return {"id": user.id, "username": user.username, "phone": user.phone, "role": user.role}


async def user_student_profile_id(db: AsyncSession, user: User) -> int:
    profile_id = await db.scalar(select(StudentProfile.id).where(StudentProfile.student_user_id == user.id))
    if profile_id:
        return int(profile_id)
    family_id = await db.scalar(select(FamilyMember.family_id).where(FamilyMember.user_id == user.id))
    if family_id is None:
        return 0
    profile_id = await db.scalar(
        select(StudentProfile.id).where(StudentProfile.family_id == family_id).order_by(StudentProfile.id)
    )
    return int(profile_id or 0)


async def user_profile_completed(db: AsyncSession, user: User) -> bool:
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.student_user_id == user.id))
    if profile is None:
        family_id = await db.scalar(select(FamilyMember.family_id).where(FamilyMember.user_id == user.id))
        if family_id is None:
            return False
        profile = await db.scalar(
            select(StudentProfile).where(StudentProfile.family_id == family_id).order_by(StudentProfile.id)
        )
    return bool(profile and profile.profile_completed)


@router.post("/register")
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    user = User(
        username=payload.username.strip(),
        phone=payload.phone.strip(),
        password_hash=hash_password(payload.password),
        role="user",
    )
    db.add(user)
    try:
        await db.flush()
        family = Family(
            name=f"{user.username}的学习空间",
            created_by=user.id,
            invite_code=f"FAM-{token_hex(4).upper()}",
        )
        db.add(family)
        await db.flush()
        db.add(FamilyMember(family_id=family.id, user_id=user.id, family_role="owner"))
        profile = StudentProfile(
            family_id=family.id,
            student_user_id=user.id,
            name=user.username,
            grade="五年级",
            learning_goal="自主提升",
            weekly_study_minutes=180,
            bind_code=f"STU-{token_hex(4).upper()}",
            bind_code_used=True,
            profile_completed=False,
        )
        db.add(profile)
        await db.flush()
        db.add(StudentSubjectProfile(
            student_profile_id=profile.id,
            subject="数学",
            recent_score=0,
            weak_points=[],
        ))
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(status_code=409, detail="用户名或手机号已存在") from exc
    return ok({
        "accessToken": create_access_token(user),
        "user": user_data(user),
        "studentProfileId": profile.id,
        "profileCompleted": False,
    }, "注册成功")


@router.post("/login")
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(or_(User.username == payload.account, User.phone == payload.account)))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="账号或密码错误")
    return ok({
        "accessToken": create_access_token(user),
        "user": user_data(user),
        "studentProfileId": await user_student_profile_id(db, user),
        "profileCompleted": await user_profile_completed(db, user),
    }, "登录成功")


@router.get("/me")
async def me(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    data = user_data(user)
    data["studentProfileId"] = await user_student_profile_id(db, user)
    data["profileCompleted"] = await user_profile_completed(db, user)
    return ok(data)
