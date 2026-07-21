from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, Paper, PaperQuestion


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


def _question_templates(subject: str, knowledge_point: str) -> list[tuple[str, list[str], int, str]]:
    if subject == "语文":
        return [
            (f"学习{knowledge_point}时，哪种方法更有效？", ["只记答案", "结合例句理解并练习", "跳过内容", "只看标题"], 1, "结合语境理解并及时练习，有助于形成稳定掌握。"),
            ("下列哪一项更适合作为阅读文章的中心概括？", ["文中的任意一句", "文章主要内容和表达重点", "最后一个词", "生字数量"], 1, "中心概括应覆盖文章主要内容和表达重点。"),
            ("遇到不理解的词语时，首先可以怎么做？", ["结合上下文推测", "直接跳过全文", "随意替换", "只看字数"], 0, "联系上下文是理解词义的重要方法。"),
            ("完成习作后，哪种检查方式更合理？", ["只检查字数", "检查内容、结构和错别字", "立即提交", "删除开头"], 1, "从内容、结构和语言三方面检查能提高习作质量。"),
            ("积累古诗词时，哪种方式更利于理解？", ["只机械抄写", "结合注释、画面和情感理解", "不读原文", "只背题目"], 1, "结合语境、画面和情感能够提升理解与记忆。"),
        ]
    if subject == "数学":
        return [
            (f"关于{knowledge_point}，下列计算结果正确的是？", ["25", "40", "50", "75"], 2, "先梳理题目条件，再按运算顺序计算。"),
            (f"解决一道{knowledge_point}问题，第一步通常应当做什么？", ["直接猜答案", "找出已知量和未知量", "跳过题目", "只看选项"], 1, "应用题先识别已知量、未知量及它们之间的关系。"),
            ("把 0.25 化成百分数是多少？", ["2.5%", "25%", "250%", "0.25%"], 1, "小数化百分数需要乘以100并添加百分号。"),
            ("一个数的 50% 是 30，这个数是多少？", ["15", "30", "60", "90"], 2, "用30除以50%，得到60。"),
            ("完成计算后，最合适的检查方法是什么？", ["估算并代回验证", "立即提交", "删除过程", "更换题目"], 0, "估算与代回可以发现数量级或运算错误。"),
        ]
    return [
        (f"学习{knowledge_point}时，哪种方法更有效？", ["只背中文", "结合语境反复使用", "跳过生词", "只看答案"], 1, "语言知识需要在语境中理解并通过输出巩固。"),
        ("Choose the correct word: I ___ a student.", ["am", "is", "are", "be"], 0, "主语 I 与 am 搭配。"),
        ("Which word means '阅读'?", ["listen", "read", "write", "speak"], 1, "read 表示阅读。"),
        ("阅读短文时，遇到生词首先可以怎么做？", ["立即放弃", "结合上下文推测", "删除句子", "只看标题"], 1, "上下文通常能提供词义线索。"),
        ("完成阅读题后，哪种复盘方式更合理？", ["只记分数", "分析定位句和错误原因", "不看解析", "重新抄题"], 1, "复盘定位依据和错误原因，才能减少重复错误。"),
    ]


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

    papers = list((await db.scalars(select(Paper).order_by(Paper.id))).all())
    for paper in papers:
        count = await db.scalar(select(func.count(PaperQuestion.id)).where(PaperQuestion.paper_id == paper.id)) or 0
        if count:
            continue
        knowledge_point = (paper.knowledge_points or ["综合"])[0]
        for sequence, (stem, options, correct_index, explanation) in enumerate(
            _question_templates(paper.subject, knowledge_point), start=1
        ):
            db.add(PaperQuestion(
                paper_id=paper.id,
                sequence=sequence,
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
