from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Paper, PaperQuestion, User
from server.schemas import GeneratePaperRequest, PaperAnalyzeRequest, PracticeAttemptCreate
from server.services.ai_paper_service import _display_name, delete_my_paper, generate_paper, list_my_papers
from server.services.learning_service import submit_attempt
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/papers", tags=["papers"])


def paper_data(row: Paper) -> dict:
    name = _display_name(row.name) if row.is_ai_generated else row.name
    return {"id": row.id, "name": name, "grade": row.grade, "subject": row.subject,
            "difficulty": row.difficulty, "knowledgePoints": row.knowledge_points,
            "questionCount": row.question_count, "suitableCourseLevel": row.suitable_course_level, "ocrText": row.ocr_text}


@router.get("")
async def list_papers(
    grade: str | None = Query(None), subject: str | None = Query(None), difficulty: str | None = Query(None),
    keyword: str | None = Query(None),
    db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user),
):
    statement = select(Paper).where(Paper.is_active.is_(True), Paper.is_ai_generated.is_(False))
    if grade: statement = statement.where(Paper.grade == grade)
    if subject: statement = statement.where(Paper.subject == subject)
    if difficulty: statement = statement.where(Paper.difficulty == difficulty)
    if keyword: statement = statement.where(Paper.name.ilike(f"%{keyword}%"))
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


@router.post("/generate")
async def generate(
    payload: GeneratePaperRequest,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
):
    paper = await generate_paper(
        db, user, payload.student_profile_id, payload.requirement,
        payload.grade, payload.subject, payload.based_on_wrong_questions,
    )
    await db.commit()
    return ok({"id": paper.id, "name": paper.name, "questionCount": paper.question_count}, "试卷已生成")


@router.get("/my/list")
async def my_papers(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    rows = await list_my_papers(db, user)
    return ok(rows)


@router.delete("/my/{paper_id}")
async def delete_my_paper_endpoint(
    paper_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await delete_my_paper(db, user, paper_id)
    await db.commit()
    return ok(None, "试卷已删除")


@router.post("/analyze")
async def analyze(payload: PaperAnalyzeRequest, _user: User = Depends(get_current_user)):
    text = payload.text
    if any(word in text for word in ("千米", "计算", "百分", "方程", "面积", "分数")):
        subject = "数学"
    elif any(word in text.lower() for word in ("english", "choose", "read", "word", "grammar")):
        subject = "英语"
    else:
        subject = "语文"
    if subject == "数学":
        candidates = ["应用题", "百分数", "几何", "计算"]
    elif subject == "英语":
        candidates = ["词汇", "语法", "阅读", "听力"]
    else:
        candidates = ["拼音", "识字写字", "阅读理解", "古诗文", "作文"]
    points = [point for point in candidates if point in text]
    if not points:
        points = ["应用题" if subject == "数学" else "阅读理解" if subject == "语文" else "阅读"]
    difficulty = "较难" if len(text) > 1000 else "中等" if len(text) > 200 else "基础"
    return ok({"subject": subject, "grade": payload.grade or "待确认", "knowledgePoints": points,
               "difficulty": difficulty, "needsConfirmation": True})


@router.get("/{paper_id}")
async def get_paper(paper_id: int, db: AsyncSession = Depends(get_db), _user: User = Depends(get_current_user)):
    row = await db.get(Paper, paper_id)
    if row is None: raise HTTPException(status_code=404, detail="试卷不存在")
    return ok(paper_data(row))

