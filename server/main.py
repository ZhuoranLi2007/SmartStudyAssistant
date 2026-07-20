import logging
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from server.api import api_router
from server.config import get_settings
from server.database import SessionLocal, init_database
from server.services.seed_service import seed_catalog

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("smartstudy")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    await init_database()
    async with SessionLocal() as session:
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
