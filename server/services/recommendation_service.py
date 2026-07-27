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


def _prefer_level(items: list, level: str, points: list[str] | None = None, limit: int = 3):
    """资源不足时把知识点和学习层次降为排序偏好，不再作为硬过滤条件。"""
    target_points = points or []
    return sorted(items, key=lambda item: (
        bool(target_points) and not any(point in (item.knowledge_points or []) for point in target_points),
        getattr(item, "level", None) != level
        and getattr(item, "suitable_course_level", None) != level,
        item.id,
    ))[:limit]


async def recommend_for_student(
    db: AsyncSession,
    user: User,
    profile: StudentProfile,
    subject: str | None = None,
    session_id: str | None = None,
) -> dict:
    requested_subject = subject or "数学"
    subject_profile = await db.scalar(
        select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == profile.id,
            StudentSubjectProfile.subject == requested_subject,
        )
    )
    reference_profile = subject_profile
    if reference_profile is None:
        reference_profile = await db.scalar(
            select(StudentSubjectProfile).where(StudentSubjectProfile.student_profile_id == profile.id)
        )
    if reference_profile is None:
        return {"missingFields": ["科目", "最近成绩", "薄弱知识点"], "recommendation": None}

    level = calculate_level(reference_profile.recent_score)
    weak_points = (subject_profile.weak_points or []) if subject_profile is not None else []

    exact_courses = list((await db.scalars(select(Course).where(
        Course.grade == profile.grade, Course.subject == requested_subject,
        Course.level == level, Course.is_active.is_(True)
    ).order_by(Course.id))).all())
    course_rows = _match_by_weak_points(exact_courses, weak_points, limit=3) if weak_points else exact_courses[:3]
    if not course_rows:
        same_grade_courses = list((await db.scalars(select(Course).where(
            Course.grade == profile.grade,
            Course.subject == requested_subject,
            Course.is_active.is_(True),
        ).order_by(Course.id))).all())
        course_rows = _prefer_level(same_grade_courses, level, weak_points)
    if not course_rows:
        same_subject_courses = list((await db.scalars(select(Course).where(
            Course.subject == requested_subject,
            Course.is_active.is_(True),
        ).order_by(Course.id))).all())
        course_rows = _prefer_level(same_subject_courses, level, weak_points)

    exact_papers = list((await db.scalars(select(Paper).where(
        Paper.grade == profile.grade, Paper.subject == requested_subject,
        Paper.suitable_course_level == level, Paper.is_active.is_(True)
    ).order_by(Paper.id))).all())
    paper_rows = _match_by_weak_points(exact_papers, weak_points, limit=3) if weak_points else exact_papers[:3]
    if not paper_rows:
        same_grade_papers = list((await db.scalars(select(Paper).where(
            Paper.grade == profile.grade,
            Paper.subject == requested_subject,
            Paper.is_active.is_(True),
        ).order_by(Paper.id))).all())
        paper_rows = _prefer_level(same_grade_papers, level, weak_points)
    if not paper_rows:
        same_subject_papers = list((await db.scalars(select(Paper).where(
            Paper.subject == requested_subject,
            Paper.is_active.is_(True),
        ).order_by(Paper.id))).all())
        paper_rows = _prefer_level(same_subject_papers, level, weak_points)

    intensity = "每周2次" if profile.weekly_study_minutes < 120 else "每周3次" if profile.weekly_study_minutes < 300 else "每周4次"
    explanation = (
        f"已为你挑选{requested_subject}{level}方向的学习资源，"
        f"建议{intensity}学习，可直接从下方卡片查看课程并配合专项练习。"
    )
    result = {
        "level": level,
        "subject": requested_subject,
        "score": reference_profile.recent_score,
        "rules": [f"优先推荐{requested_subject}资源", f"当前学习层次参考{level}"],
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
        rule_result={"level": level, "score": reference_profile.recent_score,
                     "subject": requested_subject, "weakPoints": weak_points},
        result_json=result,
        explanation=explanation,
    ))
    return {"missingFields": [], "recommendation": result}
