from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, Paper, PaperQuestion


GRADES = ["五年级", "六年级"]
SUBJECTS = ["数学", "英语"]
LEVELS = ["基础巩固型", "中等提升型", "拔高拓展型"]
DIFFICULTIES = ["基础", "中等", "较难"]
PRICES = [Decimal("69.00"), Decimal("99.00"), Decimal("139.00")]


def _question_templates(subject: str, knowledge_point: str) -> list[tuple[str, list[str], int, str]]:
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
    course_count = await db.scalar(select(func.count(Course.id))) or 0
    if course_count == 0:
        for grade in GRADES:
            for subject in SUBJECTS:
                points = ["计算", "应用题", "几何"] if subject == "数学" else ["词汇", "语法", "阅读"]
                for index, level in enumerate(LEVELS):
                    db.add(Course(
                        name=f"{grade}{subject}{level.replace('型', '')}课",
                        grade=grade,
                        subject=subject,
                        level=level,
                        difficulty=DIFFICULTIES[index],
                        suitable_for="基础知识需要巩固的学生" if index == 0 else "希望稳定提高成绩的学生" if index == 1 else "成绩优秀且希望拓展的学生",
                        knowledge_points=points,
                        description=f"围绕{subject}核心知识点设计的{level}课程，包含讲解、例题与阶段练习。",
                        price=PRICES[index],
                        total_lessons=12 + index * 4,
                    ))
        await db.flush()

    paper_count = await db.scalar(select(func.count(Paper.id))) or 0
    if paper_count == 0:
        for grade in GRADES:
            for subject in SUBJECTS:
                points = ["计算", "应用题", "几何"] if subject == "数学" else ["词汇", "语法", "阅读"]
                for index, level in enumerate(LEVELS):
                    for paper_index in (1, 2):
                        db.add(Paper(
                            name=f"{grade}{subject}{level}训练卷{paper_index}",
                            grade=grade,
                            subject=subject,
                            difficulty=DIFFICULTIES[index],
                            knowledge_points=points,
                            question_count=20 if paper_index == 1 else 25,
                            suitable_course_level=level,
                        ))
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
