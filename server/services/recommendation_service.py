from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import Course, Paper, RecommendationRecord, StudentProfile, StudentSubjectProfile, User

FOUNDATION = "基础巩固型"
IMPROVEMENT = "中等提升型"
EXTENSION = "拔高拓展型"


def calculate_level(score: float) -> str:
    if score < 60:
        return FOUNDATION
    if score < 80:
        return IMPROVEMENT
    return EXTENSION


def _match_by_weak_points(items: list, weak_points: list[str], limit: int = 5):
    """按薄弱知识点顺序匹配，每个知识点优先返回一项；未匹配时返回空列表。"""
    matched = []
    for point in weak_points:
        for item in items:
            if point in (getattr(item, "knowledge_points", None) or []) and item not in matched:
                matched.append(item)
                break
        if len(matched) >= limit:
            break
    return matched


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

    level = calculate_level(subject_profile.recent_score)
    weak_points = subject_profile.weak_points or []

    all_courses = list((await db.scalars(select(Course).where(
        Course.grade == profile.grade, Course.subject == subject_profile.subject,
        Course.level == level, Course.is_active.is_(True)
    ))).all())
    course_rows = _match_by_weak_points(all_courses, weak_points, limit=3)
    if not course_rows:
        course_rows = all_courses[:3]

    all_papers = list((await db.scalars(select(Paper).where(
        Paper.grade == profile.grade, Paper.subject == subject_profile.subject,
        Paper.suitable_course_level == level, Paper.is_active.is_(True)
    ))).all())
    paper_rows = _match_by_weak_points(all_papers, weak_points, limit=3)
    if not paper_rows:
        paper_rows = all_papers[:3]

    intensity = "每周2次" if profile.weekly_study_minutes < 120 else "每周3次" if profile.weekly_study_minutes < 300 else "每周4次"
    explanation = (
        f"根据当前成绩{subject_profile.recent_score:g}分，推荐{level}内容；"
        f"薄弱点为{'、'.join(weak_points) or '暂未记录'}，已优先匹配相关课程与试卷。"
        f"建议{intensity}学习，先完成专项训练再阶段复测。"
    )
    result = {
        "level": level,
        "subject": subject_profile.subject,
        "score": subject_profile.recent_score,
        "rules": [f"成绩{subject_profile.recent_score:g}分，对应{level}"],
        "explanation": explanation,
        "courses": [{
            "id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "level": row.level, "difficulty": row.difficulty, "price": float(row.price),
            "totalLessons": row.total_lessons, "knowledgePoints": row.knowledge_points,
            "suitableFor": row.suitable_for, "description": row.description,
        } for row in course_rows],
        "papers": [{
            "id": row.id, "name": row.name, "grade": row.grade, "subject": row.subject,
            "difficulty": row.difficulty, "questionCount": row.question_count,
            "knowledgePoints": row.knowledge_points,
        } for row in paper_rows],
    }
    db.add(RecommendationRecord(
        user_id=user.id,
        student_profile_id=profile.id,
        session_id=session_id,
        recommendation_type="COURSE_RECOMMENDATION",
        rule_result={"level": level, "score": subject_profile.recent_score, "weakPoints": weak_points},
        result_json=result,
        explanation=explanation,
    ))
    return {"missingFields": [], "recommendation": result}
