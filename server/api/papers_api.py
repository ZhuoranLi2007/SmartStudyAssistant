from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Paper, PaperQuestion, User
from server.schemas import PaperAnalyzeRequest, PracticeAttemptCreate
from server.services.learning_service import submit_attempt
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/papers", tags=["papers"])


def paper_data(row: Paper) -> dict:
    return {"id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "difficulty": row.difficulty, "knowledgePoints": row.knowledge_points,
            "questionCount": row.question_count, "suitableCourseLevel": row.suitable_course_level, "ocrText": row.ocr_text}


@router.get("")
async def list_papers(
    grade: str | None = Query(None), subject: str | None = Query(None), difficulty: str | None = Query(None),
    db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user),
):
    statement = select(Paper).where(Paper.is_active.is_(True))
    if grade: statement = statement.where(Paper.grade == grade)
    if subject: statement = statement.where(Paper.subject == subject)
    if difficulty: statement = statement.where(Paper.difficulty == difficulty)
    rows = list((await db.scalars(statement.order_by(Paper.id))).all())
    return ok([paper_data(row) for row in rows])


@router.get("/{paper_id}/questions")
async def paper_questions(paper_id: int, db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user)):
    paper = await db.get(Paper, paper_id)
    if paper is None:
        raise HTTPException(status_code=404, detail="试卷不存在")
    rows = list((await db.scalars(select(PaperQuestion).where(
        PaperQuestion.paper_id == paper_id
    ).order_by(PaperQuestion.sequence))).all())
    return ok({"paper": paper_data(paper), "questions": [{
        "id": row.id, "sequence": row.sequence, "stem": row.stem,
        "options": row.options_json, "knowledgePoint": row.knowledge_point,
    } for row in rows]})


@router.post("/{paper_id}/attempts")
async def create_attempt(
    paper_id: int, payload: PracticeAttemptCreate,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    result = await submit_attempt(
        db, user, payload.student_profile_id, paper_id,
        [(item.question_id, item.selected_index) for item in payload.answers],
    )
    await db.commit()
    return ok(result, "答题结果已保存")


@router.get("/{paper_id}")
async def get_paper(paper_id: int, db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user)):
    row = await db.get(Paper, paper_id)
    if row is None: raise HTTPException(status_code=404, detail="试卷不存在")
    return ok(paper_data(row))


@router.post("/analyze")
async def analyze(payload: PaperAnalyzeRequest, _user: User = Depends(get_current_user)):
    text = payload.text
    subject = "数学" if any(word in text for word in ("千米", "计算", "百分", "方程")) else "英语"
    candidates = ["应用题", "百分数", "几何"] if subject == "数学" else ["词汇", "语法", "阅读"]
    points = [point for point in candidates if point in text]
    if not points: points = ["应用题" if subject == "数学" else "阅读"]
    difficulty = "较难" if len(text) > 1000 else "中等" if len(text) > 200 else "基础"
    return ok({"subject": subject, "grade": payload.grade or "待确认", "knowledgePoints": points,
               "difficulty": difficulty, "needsConfirmation": True})
