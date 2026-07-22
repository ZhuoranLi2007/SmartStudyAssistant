import hashlib
import json
from decimal import Decimal
from pathlib import Path

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, Paper, PaperQuestion, PracticeAnswer, PracticeAttempt, WrongQuestion


GRADES = ["一年级", "二年级", "三年级", "四年级", "五年级", "六年级"]
SUBJECTS = ["语文", "数学", "英语"]
LEVELS = ["基础巩固型", "中等提升型", "拔高拓展型"]
DIFFICULTIES = ["基础", "中等", "较难"]
PRICES = [Decimal("69.00"), Decimal("99.00"), Decimal("139.00")]
LEGACY_PAIRS = [("五年级", "数学"), ("五年级", "英语"), ("六年级", "数学"), ("六年级", "英语")]


def _catalog_pairs() -> list[tuple[str, str]]:
    """旧组合优先，保证全新数据库中的原有1-12课程、1-24试卷ID不变。"""
    result = list(LEGACY_PAIRS)
    result.extend((grade, subject) for grade in GRADES for subject in SUBJECTS if (grade, subject) not in LEGACY_PAIRS)
    return result


def _knowledge_points(grade: str, subject: str) -> list[str]:
    lower = grade in ("一年级", "二年级")
    middle = grade in ("三年级", "四年级")
    if subject == "语文":
        if lower:
            return ["拼音", "识字写字", "看图写话"]
        if middle:
            return ["字词基础", "阅读理解", "习作"]
        return ["阅读理解", "古诗文", "作文"]
    if subject == "数学":
        if lower:
            return ["口算", "加减法", "应用题"]
        if middle:
            return ["乘除法", "小数", "图形面积"]
        return ["分数", "百分数", "应用题"]
    if lower:
        return ["字母", "自然拼读", "基础词汇"]
    if middle:
        return ["词汇", "句型", "听力"]
    return ["词汇", "语法", "阅读理解"]


def _paper_questions_path() -> Path:
    """试卷题目 JSON 文件路径。"""
    return Path(__file__).resolve().parent.parent / "data" / "paper_questions.json"


def _paper_questions_hash_path() -> Path:
    """记录试卷题目 JSON 文件 hash 的标记文件路径。"""
    return Path(__file__).resolve().parent.parent / "data" / ".paper_questions_hash"


def _paper_questions_hash() -> str:
    """计算试卷题目 JSON 文件内容的 sha256 hash。"""
    path = _paper_questions_path()
    if not path.exists():
        return ""
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except Exception:
        return ""


def _load_paper_questions() -> dict[str, list[tuple[str, list[str], int, str, int]]]:
    """从 JSON 加载每套试卷的 5 道题目，返回 {试卷名: [(stem, options, correct_index, explanation, question_no), ...]}。"""
    path = _paper_questions_path()
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as fp:
            raw = json.load(fp)
    except Exception:
        return {}

    letter_to_index = {"A": 0, "B": 1, "C": 2, "D": 3}
    result: dict[str, list[tuple[str, list[str], int, str, int]]] = {}
    question_no = 1
    for paper_name, items in raw.items():
        templates: list[tuple[str, list[str], int, str, int]] = []
        for item in items:
            stem = (item.get("stem") or "").strip()
            options = item.get("options") or []
            options = [str(opt).strip() for opt in options]
            correct_letter = str(item.get("correct") or "").strip().upper()
            correct_index = letter_to_index.get(correct_letter, 0)
            explanation = (item.get("explanation") or "").strip()
            if not stem or len(options) != 4:
                continue
            templates.append((stem, options, correct_index, explanation, question_no))
            question_no += 1
        if templates:
            result[paper_name] = templates
    return result


def _questions_match(
    questions: list[PaperQuestion],
    templates: list[tuple[str, list[str], int, str, int]],
) -> bool:
    """检查数据库中的题目与 JSON 模板是否完全一致。"""
    if len(questions) != len(templates):
        return False
    for question, (stem, options, correct_index, explanation, question_no) in zip(questions, templates):
        if question.question_no != question_no:
            return False
        if question.stem.strip() != stem:
            return False
        if question.options_json != options:
            return False
        if question.correct_index != correct_index:
            return False
        if (question.explanation or "").strip() != explanation:
            return False
    return True


async def seed_catalog(db: AsyncSession) -> None:
    # 课程目录：五年级数学 5 个薄弱知识点 × 3 个层次 = 15 门课
    knowledge_points = ["分数", "小数", "百分数", "应用题", "几何"]
    levels = ["基础巩固型", "中等提升型", "拔高拓展型"]
    difficulties = ["基础", "中等", "较难"]
    suitable_for = [
        "基础知识需要巩固的学生",
        "希望稳定提高成绩的学生",
        "成绩优秀且希望拓展的学生",
    ]

    def course_description(point: str, level: str) -> str:
        return f"围绕五年级数学{point}知识点设计的{level}课程，包含讲解、例题与阶段练习。"

    target_courses = []
    for level_index, level in enumerate(levels):
        for point in knowledge_points:
            target_courses.append({
                "name": f"{point}{level.replace('型', '')}课程",
                "grade": "五年级",
                "subject": "数学",
                "level": level,
                "difficulty": difficulties[level_index],
                "suitable_for": suitable_for[level_index],
                "knowledge_points": [point],
                "description": course_description(point, level),
                "price": PRICES[level_index],
                "total_lessons": 12 + level_index * 4,
            })
    target_names = {c["name"] for c in target_courses}

    # 停用旧课程，确保首页只显示这 15 门
    for course in list((await db.scalars(select(Course))).all()):
        course.is_active = course.name in target_names

    existing_course_names = set((await db.scalars(select(Course.name))).all())
    for data in target_courses:
        if data["name"] in existing_course_names:
            continue
        db.add(Course(**data))
        existing_course_names.add(data["name"])
    await db.flush()

    # 试卷目录：五年级数学 5 个薄弱知识点 × 3 个层次 = 15 套卷，每套 5 题
    target_papers = []
    for level_index, level in enumerate(levels):
        for point in knowledge_points:
            target_papers.append({
                "name": f"{point}{level.replace('型', '')}题型",
                "grade": "五年级",
                "subject": "数学",
                "difficulty": DIFFICULTIES[level_index],
                "knowledge_points": [point],
                "question_count": 5,
                "suitable_course_level": level,
            })
    target_paper_names = {p["name"] for p in target_papers}

    # 停用旧试卷
    for paper in list((await db.scalars(select(Paper))).all()):
        paper.is_active = paper.name in target_paper_names

    existing_paper_names = set((await db.scalars(select(Paper.name))).all())
    for data in target_papers:
        if data["name"] in existing_paper_names:
            continue
        db.add(Paper(**data))
        existing_paper_names.add(data["name"])
    await db.flush()

    courses = list((await db.scalars(select(Course).order_by(Course.id))).all())
    for course in courses:
        try:
            index = LEVELS.index(course.level)
        except ValueError:
            index = 1
        if course.price is None:
            course.price = PRICES[index]
        if not course.total_lessons:
            course.total_lessons = 12 + index * 4

    questions_by_name = _load_paper_questions()
    papers = list((await db.scalars(select(Paper).order_by(Paper.id))).all())
    target_paper_ids = [paper.id for paper in papers if paper.name in target_paper_names]

    # 检测每套目标试卷的题目是否与 JSON 完全一致；任何不一致或 JSON 发生变化都清空后重新生成
    current_hash = _paper_questions_hash()
    hash_marker = _paper_questions_hash_path()
    previous_hash = ""
    if hash_marker.exists():
        try:
            previous_hash = hash_marker.read_text(encoding="utf-8").strip()
        except Exception:
            previous_hash = ""
    need_reset = current_hash != previous_hash

    if not need_reset:
        for paper in papers:
            if paper.id not in target_paper_ids:
                continue
            templates = questions_by_name.get(paper.name, [])
            if not templates:
                continue
            existing = list((await db.scalars(
                select(PaperQuestion).where(PaperQuestion.paper_id == paper.id).order_by(PaperQuestion.sequence)
            )).all())
            if not _questions_match(existing, templates):
                need_reset = True
                break

    if need_reset and target_paper_ids:
        target_question_ids = select(PaperQuestion.id).where(PaperQuestion.paper_id.in_(target_paper_ids))
        await db.execute(delete(PracticeAnswer).where(PracticeAnswer.question_id.in_(target_question_ids)))
        await db.execute(delete(WrongQuestion).where(WrongQuestion.question_id.in_(target_question_ids)))
        await db.execute(delete(PaperQuestion).where(PaperQuestion.paper_id.in_(target_paper_ids)))
        await db.commit()
        try:
            hash_marker.write_text(current_hash, encoding="utf-8")
        except Exception:
            pass

    for paper in papers:
        if paper.id not in target_paper_ids:
            continue
        templates = questions_by_name.get(paper.name, [])
        existing_count = await db.scalar(
            select(func.count(PaperQuestion.id)).where(PaperQuestion.paper_id == paper.id)
        ) or 0
        if existing_count > 0:
            continue
        knowledge_point = (paper.knowledge_points or ["综合"])[0]
        for sequence, (stem, options, correct_index, explanation, question_no) in enumerate(templates, start=1):
            db.add(PaperQuestion(
                paper_id=paper.id,
                sequence=sequence,
                question_no=question_no,
                stem=stem,
                options_json=options,
                correct_index=correct_index,
                explanation=explanation,
                knowledge_point=knowledge_point,
            ))
    await db.commit()


async def clear_user_data(db: AsyncSession) -> None:
    """清空所有账号与学习数据，保留课程/试卷目录。注册后个人中心从 0 开始。"""
    from sqlalchemy import text

    try:
        await db.execute(text("SET FOREIGN_KEY_CHECKS=0"))
    except Exception:
        pass
    tables = [
        "practice_answers",
        "practice_attempts",
        "wrong_questions",
        "favorites",
        "study_tasks",
        "course_enrollments",
        "course_orders",
        "chat_messages",
        "ai_requests",
        "tool_call_logs",
        "recommendation_records",
        "chat_sessions",
        "student_subject_profiles",
        "student_profiles",
        "family_members",
        "families",
        "users",
    ]
    for table in tables:
        try:
            await db.execute(text(f"DELETE FROM {table}"))
            await db.commit()
        except Exception:
            await db.rollback()
    try:
        await db.execute(text("SET FOREIGN_KEY_CHECKS=1"))
        await db.commit()
    except Exception:
        await db.rollback()
