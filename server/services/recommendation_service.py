from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, Paper, RecommendationRecord, StudentProfile, StudentSubjectProfile, User

FOUNDATION = "基础巩固型"
IMPROVEMENT = "中等提升型"
EXTENSION = "拔高拓展型"


def calculate_level(score: float, weak_points: list[str], learning_goal: str) -> tuple[str, list[str]]:
    rules: list[str] = []
    if score < 70:
        level = FOUNDATION
        rules.append("成绩低于70分，初始等级为基础巩固型")
    elif score < 90:
        level = IMPROVEMENT
        rules.append("成绩在70至89分之间，初始等级为中等提升型")
    else:
        level = EXTENSION
        rules.append("成绩达到90分，初始等级为拔高拓展型")

    if len(weak_points) >= 3:
        old_level = level
        level = FOUNDATION if level == IMPROVEMENT else IMPROVEMENT if level == EXTENSION else FOUNDATION
        rules.append(f"薄弱点达到3项，等级由{old_level}下调为{level}")

    if "巩固基础" in learning_goal:
        level = FOUNDATION
        rules.append("学习目标为巩固基础，最终等级限定为基础巩固型")

    if ("竞赛" in learning_goal or "拓展" in learning_goal) and not (score >= 90 and len(weak_points) <= 1):
        if level == EXTENSION:
            level = IMPROVEMENT
        rules.append("当前成绩或薄弱点数量不满足拔高条件，暂不推荐拔高拓展型")
    return level, rules


async def recommend_for_student(
    db: AsyncSession,
    user: User,
    profile: StudentProfile,
    subject: str | None = None,
    session_id: str | None = None,
) -> dict:
    subject_profile = await db.scalar(
        select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == profile.id,
            StudentSubjectProfile.subject == (subject or "数学"),
        )
    )
    if subject_profile is None:
        subject_profile = await db.scalar(
            select(StudentSubjectProfile).where(StudentSubjectProfile.student_profile_id == profile.id)
        )
    if subject_profile is None:
        return {"missingFields": ["科目", "最近成绩", "薄弱知识点"], "recommendation": None}

    level, rules = calculate_level(subject_profile.recent_score, subject_profile.weak_points, profile.learning_goal)
    course_rows = list((await db.scalars(select(Course).where(
        Course.grade == profile.grade, Course.subject == subject_profile.subject, Course.level == level, Course.is_active.is_(True)
    ).limit(3))).all())
    paper_rows = list((await db.scalars(select(Paper).where(
        Paper.grade == profile.grade, Paper.subject == subject_profile.subject,
        Paper.suitable_course_level == level, Paper.is_active.is_(True)
    ).limit(3))).all())
    intensity = "每周2次" if profile.weekly_study_minutes < 120 else "每周3次" if profile.weekly_study_minutes < 300 else "每周4次"
    explanation = (
        f"建议选择{level}。孩子当前{subject_profile.subject}成绩为{subject_profile.recent_score:g}分，"
        f"薄弱点为{'、'.join(subject_profile.weak_points) or '暂未记录'}。建议{intensity}学习，先完成专项训练再阶段复测。"
    )
    result = {
        "level": level,
        "subject": subject_profile.subject,
        "score": subject_profile.recent_score,
        "rules": rules,
        "explanation": explanation,
        "courses": [{"id": row.id, "name": row.name, "level": row.level} for row in course_rows],
        "papers": [{"id": row.id, "name": row.name, "difficulty": row.difficulty} for row in paper_rows],
    }
    db.add(RecommendationRecord(
        user_id=user.id,
        student_profile_id=profile.id,
        session_id=session_id,
        recommendation_type="COURSE_RECOMMENDATION",
        rule_result={"level": level, "rules": rules},
        result_json=result,
        explanation=explanation,
    ))
    return {"missingFields": [], "recommendation": result}
