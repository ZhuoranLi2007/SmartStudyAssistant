from fastapi import APIRouter

from server.api import (
    ai_api,
    auth_api,
    chat_api,
    courses_api,
    families_api,
    favorites_api,
    home_api,
    papers_api,
    speech_api,
    students_api,
    study_plan_api,
)

api_router = APIRouter(prefix="/api")
api_router.include_router(auth_api.router)
api_router.include_router(families_api.router)
api_router.include_router(students_api.router)
api_router.include_router(courses_api.router)
api_router.include_router(papers_api.router)
api_router.include_router(study_plan_api.router)
api_router.include_router(home_api.router)
api_router.include_router(chat_api.router)
api_router.include_router(ai_api.router)
api_router.include_router(favorites_api.router)
api_router.include_router(speech_api.router)
