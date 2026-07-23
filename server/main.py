import logging
from contextlib import asynccontextmanager
from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from server.api import api_router
from server.config import get_settings
from server.database import SessionLocal, engine, init_database
from server.services.seed_service import clear_user_data, seed_catalog

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("smartstudy")
USER_DATA_CLEARED_MARKER = Path(__file__).resolve().parent / ".user_data_cleared"


async def _ensure_favorites_table() -> None:
    """旧 favorites 表可能缺 type 等列，按需重建。"""
    try:
        async with engine.begin() as connection:
            result = await connection.execute(text(
                "SELECT COUNT(*) FROM information_schema.COLUMNS "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'favorites' AND COLUMN_NAME = 'type'"
            ))
            has_type = int(result.scalar() or 0) > 0
            if has_type:
                return
            await connection.execute(text("DROP TABLE IF EXISTS favorites"))
            await connection.execute(text("""
                CREATE TABLE favorites (
                    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                    student_profile_id INT NOT NULL,
                    target_id INT NOT NULL,
                    type VARCHAR(20) NOT NULL,
                    title VARCHAR(150) NOT NULL,
                    subtitle VARCHAR(150) NOT NULL DEFAULT '',
                    tag VARCHAR(50) NOT NULL DEFAULT '',
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    UNIQUE KEY uq_student_favorite (student_profile_id, target_id, type),
                    KEY ix_favorites_student_profile_id (student_profile_id),
                    KEY ix_favorites_target_id (target_id),
                    KEY ix_favorites_type (type),
                    CONSTRAINT fk_favorites_student FOREIGN KEY (student_profile_id)
                        REFERENCES student_profiles(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """))
            logger.info("favorites 表已按最新结构重建")
    except Exception as exc:
        logger.info("favorites schema ensure skipped: %s", exc)


async def _ensure_schema_patches() -> None:
    """兼容已有数据库结构。"""
    patches = [
        "ALTER TABLE course_enrollments MODIFY COLUMN order_id INT NULL",
        "ALTER TABLE student_profiles ADD COLUMN profile_completed TINYINT(1) NOT NULL DEFAULT 0",
        "ALTER TABLE paper_questions ADD COLUMN question_no INT NULL",
        "ALTER TABLE wrong_questions ADD COLUMN question_no INT NOT NULL DEFAULT 0",
        "ALTER TABLE paper_questions ADD UNIQUE KEY uq_paper_question_no (question_no)",
        "ALTER TABLE papers ADD COLUMN is_ai_generated TINYINT(1) NOT NULL DEFAULT 0",
        "ALTER TABLE papers ADD COLUMN created_by INT NULL",
        "ALTER TABLE papers ADD KEY ix_papers_created_by (created_by)",
    ]
    for sql in patches:
        try:
            async with engine.begin() as connection:
                await connection.execute(text(sql))
        except Exception as exc:
            logger.info("schema patch skipped or already applied: %s", exc)
    try:
        async with engine.begin() as connection:
            await connection.execute(text("""
                UPDATE wrong_questions wq
                JOIN paper_questions pq ON wq.question_id = pq.id
                SET wq.question_no = pq.question_no
                WHERE pq.question_no > 0 AND wq.question_no = 0
            """))
    except Exception as exc:
        logger.info("wrong_questions question_no repair skipped: %s", exc)
    await _ensure_favorites_table()



@asynccontextmanager
async def lifespan(_app: FastAPI):
    await init_database()
    await _ensure_schema_patches()
    async with SessionLocal() as session:
        if not USER_DATA_CLEARED_MARKER.exists():
            await clear_user_data(session)
            USER_DATA_CLEARED_MARKER.write_text("cleared", encoding="utf-8")
            logger.info("已清空全部账号与学习数据，请重新注册（仅执行一次）")
        await seed_catalog(session)
    yield


settings = get_settings()
app = FastAPI(title=settings.app_name, version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(api_router)


@app.middleware("http")
async def request_context(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid4()))
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    logger.info("%s %s %s %s", request.method, request.url.path, response.status_code, request_id)
    return response


@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException):
    return JSONResponse(status_code=exc.status_code, content={"code": exc.status_code, "message": str(exc.detail), "data": None, "requestId": str(uuid4())})


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_request: Request, exc: RequestValidationError):
    return JSONResponse(status_code=422, content={"code": 422, "message": "请求参数校验失败", "data": exc.errors(), "requestId": str(uuid4())})


@app.get("/health")
async def health():
    return {"status": "ok", "environment": settings.environment, "aiProvider": settings.ai_provider}


@app.get("/api/health")
async def api_health():
    return {"code": 0, "message": "success", "data": {
        "status": "ok", "environment": settings.environment, "aiProvider": settings.ai_provider,
    }, "requestId": str(uuid4())}
