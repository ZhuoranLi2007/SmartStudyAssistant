import json
import re

from fastapi import HTTPException
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from server.ai.providers import ProviderError, ProviderRouter
from server.models import Favorite, Paper, PaperQuestion, StudyTask, User, WrongQuestion


_RE_AI_PAPER_NAME = re.compile(r"^AI组卷-(\d+)-(.+)-u(\d+)$")
_RE_AI_PAPER_NAME_LEGACY = re.compile(r"^AI组卷-(\d+)-(.+)$")
_RE_OLD_UNIQUE_SUFFIX = re.compile(r"-\d{10}-[a-f0-9]{6}$")


_SYSTEM_PROMPT = """你是一位资深小学数学出题老师。请根据用户要求生成一套小学数学选择题试卷。
要求：
1. 必须生成 5 道选择题，每道题 4 个选项；
2. 题干清晰、选项合理、有唯一正确答案；
3. 每道题附带解析，说明解题思路；
4. 难度只能是"基础"、"中等"或"较难"之一；
5. 年级只能是"一年级"到"六年级"之一；
6. 学科固定为"数学"；
7. 输出必须是合法的 JSON，不要任何 Markdown 代码块标记。

JSON 格式如下：
{
  "name": "试卷名称（简洁，不超过30字）",
  "subject": "数学",
  "grade": "六年级",
  "difficulty": "中等",
  "knowledgePoints": ["百分数"],
  "questions": [
    {
      "stem": "题干内容",
      "options": ["选项A", "选项B", "选项C", "选项D"],
      "correctIndex": 1,
      "explanation": "解析内容",
      "knowledgePoint": "知识点名称"
    }
  ]
}

注意：correctIndex 是正确选项在 options 数组中的下标，从 0 开始，即 0=A、1=B、2=C、3=D。"""


def _safe_json_loads(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            try:
                return json.loads(text[start : end + 1])
            except json.JSONDecodeError:
                pass
        raise ValueError(f"AI 返回不是合法 JSON: {exc}") from exc


def _build_prompt(requirement: str, grade: str, subject: str, wrong_questions: list[dict]) -> str:
    lines = [
        f"请为用户生成一套小学{subject}试卷。",
        f"年级：{grade}",
        f"用户要求：{requirement}",
    ]
    if wrong_questions:
        lines.append("\n该学生近期有如下错题，请针对薄弱点设计相似但不重复的题目：")
        for idx, item in enumerate(wrong_questions[:10], start=1):
            lines.append(f"{idx}. {item.get('question', '')}（知识点：{item.get('knowledgePoint', '')}，答错{item.get('wrongCount', 1)}次）")
    return "\n".join(lines)


_DEFAULT_PAPER = {
    "name": "AI 组卷（演示）",
    "subject": "数学",
    "grade": "六年级",
    "difficulty": "中等",
    "knowledgePoints": ["综合"],
    "questions": [
        {
            "stem": "计算：1/2 + 1/3 = ？",
            "options": ["2/5", "5/6", "1/6", "1"],
            "correctIndex": 1,
            "explanation": "通分后相加：1/2 + 1/3 = 3/6 + 2/6 = 5/6。",
            "knowledgePoint": "分数加法"
        },
        {
            "stem": "把 0.25 化成百分数是多少？",
            "options": ["2.5%", "25%", "0.25%", "250%"],
            "correctIndex": 1,
            "explanation": "0.25 = 25%。",
            "knowledgePoint": "小数与百分数"
        },
        {
            "stem": "一个数的 20% 是 40，这个数是多少？",
            "options": ["8", "200", "100", "400"],
            "correctIndex": 1,
            "explanation": "40 ÷ 20% = 40 ÷ 0.2 = 200。",
            "knowledgePoint": "百分数应用"
        },
        {
            "stem": "比较大小：3/4 ○ 2/3，○ 里应填什么？",
            "options": [">", "<", "=", "无法比较"],
            "correctIndex": 0,
            "explanation": "通分比较：3/4 = 9/12，2/3 = 8/12，所以 3/4 > 2/3。",
            "knowledgePoint": "分数比较"
        },
        {
            "stem": "长方形长 8 厘米，宽 5 厘米，周长是多少厘米？",
            "options": ["13", "26", "40", "18"],
            "correctIndex": 1,
            "explanation": "长方形周长 = (长 + 宽) × 2 = (8 + 5) × 2 = 26 厘米。",
            "knowledgePoint": "长方形周长"
        },
    ],
}


async def generate_paper(
    db: AsyncSession,
    user: User,
    student_profile_id: int,
    requirement: str,
    grade: str,
    subject: str = "数学",
    based_on_wrong_questions: bool = False,
) -> Paper:
    is_wrong_review = based_on_wrong_questions or "错题" in requirement
    wrong_items: list[dict] = []
    if is_wrong_review and student_profile_id > 0:
        rows = list((await db.scalars(select(WrongQuestion).where(
            WrongQuestion.student_profile_id == student_profile_id,
            WrongQuestion.mastered.is_(False),
        ).order_by(WrongQuestion.wrong_count.desc()).limit(10))).all())
        wrong_items = [{
            "question": row.question_text,
            "knowledgePoint": row.knowledge_point,
            "wrongCount": row.wrong_count,
        } for row in rows]

    provider = ProviderRouter()
    prompt = _build_prompt(requirement, grade, subject, wrong_items)
    data: dict | None = None
    try:
        result = await provider.complete([
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ], json_mode=True, fallback_content="")
        if result.model.startswith("mock"):
            data = _DEFAULT_PAPER
        else:
            data = _safe_json_loads(result.content)
    except ProviderError as exc:
        raise HTTPException(status_code=503, detail=f"AI 服务不可用：{exc.message}") from exc
    except ValueError:
        data = _DEFAULT_PAPER

    if data is None:
        data = _DEFAULT_PAPER
    return await _save_generated_paper(db, user, data, requirement, is_wrong_review)


async def _save_generated_paper(
    db: AsyncSession,
    user: User,
    data: dict,
    requirement: str,
    is_wrong_review: bool,
) -> Paper:
    questions_data = data.get("questions") or []
    if len(questions_data) != 5:
        raise HTTPException(status_code=502, detail=f"AI 生成题目数量异常，期望 5 道，实际 {len(questions_data)} 道")

    generated_count = await db.scalar(select(func.count(Paper.id)).where(
        Paper.is_ai_generated.is_(True),
        Paper.created_by == user.id,
        Paper.is_active.is_(True),
    ))
    serial_number = (generated_count or 0) + 1

    if is_wrong_review:
        unique_name = f"AI组卷-{serial_number}-错题复习-u{user.id}"
    else:
        ai_name = str(data.get("name") or "组卷").strip()
        if not ai_name:
            ai_name = "组卷"
        unique_name = f"AI组卷-{serial_number}-{ai_name}-u{user.id}"

    paper = Paper(
        name=unique_name,
        grade=str(data.get("grade") or "六年级").strip(),
        subject=str(data.get("subject") or "数学").strip(),
        difficulty=str(data.get("difficulty") or "中等").strip(),
        knowledge_points=data.get("knowledgePoints") or ["综合"],
        question_count=5,
        suitable_course_level="AI组卷",
        is_ai_generated=True,
        created_by=user.id,
        is_active=True,
    )
    db.add(paper)
    await db.flush()

    max_no_row = await db.scalar(select(PaperQuestion.question_no).order_by(PaperQuestion.question_no.desc()).limit(1))
    next_no = (max_no_row or 0) + 1

    for sequence, item in enumerate(questions_data, start=1):
        options = item.get("options") or []
        correct_index = int(item.get("correctIndex", 0))
        if len(options) != 4 or correct_index < 0 or correct_index >= len(options):
            raise HTTPException(status_code=502, detail=f"第 {sequence} 题选项或正确答案格式异常")
        db.add(PaperQuestion(
            paper_id=paper.id,
            sequence=sequence,
            question_no=next_no + sequence - 1,
            stem=str(item.get("stem") or "").strip(),
            options_json=options,
            correct_index=correct_index,
            explanation=str(item.get("explanation") or "").strip(),
            knowledge_point=str(item.get("knowledgePoint") or "").strip(),
        ))

    await db.flush()
    return paper


def _display_name(raw_name: str) -> str:
    name = re.sub(r"-u\d+$", "", raw_name)
    return re.sub(_RE_OLD_UNIQUE_SUFFIX, "", name)


def _extract_ai_paper_content(raw_name: str) -> str:
    match = _RE_AI_PAPER_NAME.match(raw_name)
    if match:
        return match.group(2)
    match = _RE_AI_PAPER_NAME_LEGACY.match(raw_name)
    if match:
        return match.group(2)
    return _display_name(raw_name)


async def _renumber_my_papers(db: AsyncSession, user: User) -> None:
    rows = list((await db.scalars(select(Paper).where(
        Paper.is_ai_generated.is_(True),
        Paper.created_by == user.id,
        Paper.is_active.is_(True),
    ).order_by(Paper.created_at.asc(), Paper.id.asc()))).all())
    for index, row in enumerate(rows, start=1):
        content = _extract_ai_paper_content(row.name)
        display_name = f"AI组卷-{index}-{content}"
        row.name = f"{display_name}-u{user.id}"
        await db.execute(update(StudyTask).where(
            StudyTask.task_type == "试卷",
            StudyTask.target_id == row.id,
        ).values(name=display_name))
        await db.execute(update(Favorite).where(
            Favorite.type == "paper",
            Favorite.target_id == row.id,
        ).values(title=display_name))


async def delete_my_paper(db: AsyncSession, user: User, paper_id: int) -> None:
    paper = await db.get(Paper, paper_id)
    if paper is None or not paper.is_ai_generated or paper.created_by != user.id:
        raise HTTPException(status_code=404, detail="试卷不存在或无权删除")
    paper.is_active = False
    await db.execute(delete(StudyTask).where(
        StudyTask.task_type == "试卷",
        StudyTask.target_id == paper_id,
    ))
    await db.execute(delete(Favorite).where(
        Favorite.type == "paper",
        Favorite.target_id == paper_id,
    ))
    await db.flush()
    await _renumber_my_papers(db, user)


async def list_my_papers(db: AsyncSession, user: User) -> list[dict]:
    rows = list((await db.scalars(select(Paper).where(
        Paper.is_ai_generated.is_(True),
        Paper.created_by == user.id,
        Paper.is_active.is_(True),
    ).order_by(Paper.created_at.desc()))).all())
    return [{
        "id": row.id,
        "name": _display_name(row.name),
        "grade": row.grade,
        "subject": row.subject,
        "difficulty": row.difficulty,
        "knowledgePoints": row.knowledge_points,
        "questionCount": row.question_count,
        "createdAt": row.created_at.isoformat(),
    } for row in rows]
