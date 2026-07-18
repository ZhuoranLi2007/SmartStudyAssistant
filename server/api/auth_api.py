from secrets import token_hex

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Family, FamilyMember, User
from server.schemas import LoginRequest, RegisterRequest
from server.utils.responses import ok
from server.utils.security import create_access_token, get_current_user, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def user_data(user: User) -> dict:
    return {"id": user.id, "username": user.username, "phone": user.phone, "role": user.role}


@router.post("/register")
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    user = User(
        username=payload.username.strip(), phone=payload.phone.strip(),
        password_hash=hash_password(payload.password), role=payload.role,
    )
    db.add(user)
    try:
        await db.flush()
        if user.role == "parent":
            family = Family(name=f"{user.username}的家庭", created_by=user.id, invite_code=f"FAM-{token_hex(4).upper()}")
            db.add(family)
            await db.flush()
            db.add(FamilyMember(family_id=family.id, user_id=user.id, family_role="parent"))
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(status_code=409, detail="用户名或手机号已存在") from exc
    return ok({"accessToken": create_access_token(user), "user": user_data(user)}, "注册成功")


@router.post("/login")
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(or_(User.username == payload.account, User.phone == payload.account)))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="账号或密码错误")
    return ok({"accessToken": create_access_token(user), "user": user_data(user)}, "登录成功")


@router.get("/me")
async def me(user: User = Depends(get_current_user)):
    return ok(user_data(user))
