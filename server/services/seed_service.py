from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, Paper


async def seed_catalog(db: AsyncSession) -> None:
    course_count = await db.scalar(select(func.count(Course.id)))
    if course_count and course_count > 0:
        return
    grades = ["五年级", "六年级"]
    subjects = ["数学", "英语"]
    levels = ["基础巩固型", "中等提升型", "拔高拓展型"]
    difficulties = ["基础", "中等", "较难"]
    for grade in grades:
        for subject in subjects:
            points = ["计算", "应用题", "几何"] if subject == "数学" else ["词汇", "语法", "阅读"]
            for index, level in enumerate(levels):
                course = Course(
                    name=f"{grade}{subject}{level.replace('型', '')}课",
                    grade=grade,
                    subject=subject,
                    level=level,
                    difficulty=difficulties[index],
                    suitable_for="基础知识需要巩固的学生" if index == 0 else "希望稳定提高成绩的学生" if index == 1 else "成绩优秀且希望拓展的学生",
                    knowledge_points=points,
                    description=f"围绕{subject}核心知识点设计的{level}课程，包含讲解、例题与阶段练习。",
                )
                db.add(course)
                for paper_index in (1, 2):
                    db.add(Paper(
                        name=f"{grade}{subject}{level}训练卷{paper_index}",
                        grade=grade,
                        subject=subject,
                        difficulty=difficulties[index],
                        knowledge_points=points,
                        question_count=20 if paper_index == 1 else 25,
                        suitable_course_level=level,
                    ))
    await db.commit()
