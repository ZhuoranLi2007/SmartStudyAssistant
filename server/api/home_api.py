from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models import Course, Paper, StudentProfile, StudentSubjectProfile, StudyTask, User
from server.services.access_service import ensure_student_access, get_user_family_id
from server.utils.responses import ok
from server.utils.security import get_current_user

router = APIRouter(prefix="/home", tags=["home"])


def _course_image(index: int) -> str:
    return ("COURSE_1", "COURSE_3", "COURSE_4", "COURSE_5", "COURSE_9", "COURSE_10")[index % 6]


def _course_data(course: Course, index: int, reason: str = "") -> dict:
    price = float(course.price)
    return {
        "id": course.id,
        "name": course.name,
        "grade": course.grade,
        "subject": course.subject,
        "difficulty": course.difficulty,
        "courseType": course.level,
        "priceText": "免费" if price == 0 else f"¥{price:g}",
        "imageKey": _course_image(index),
        "recommendReason": reason,
    }


def _paper_data(paper: Paper, index: int) -> dict:
    return {
        "id": paper.id,
        "name": paper.name,
        "grade": paper.grade,
        "subject": paper.subject,
        "difficulty": paper.difficulty,
        "questionCount": paper.question_count,
        "imageKey": "PAPER_MATH" if paper.subject == "数学" else "PAPER_ENGLISH",
    }


async def _accessible_profile(
    db: AsyncSession,
    user: User,
    student_profile_id: int | None,
) -> StudentProfile | None:
    if student_profile_id is not None and student_profile_id > 0:
        try:
            return await ensure_student_access(db, user, student_profile_id)
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
    profile = await db.scalar(select(StudentProfile).where(StudentProfile.student_user_id == user.id))
    if profile is not None:
        return profile
    family_id = await get_user_family_id(db, user.id)
    if family_id is None:
        return None
    return await db.scalar(select(StudentProfile).where(StudentProfile.family_id == family_id).order_by(StudentProfile.id))


@router.get("")
async def home_data(
    student_profile_id: int | None = Query(None),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    profile = await _accessible_profile(db, user, student_profile_id)
    subject_profile = None
    if profile is not None:
        subject_profile = await db.scalar(select(StudentSubjectProfile).where(
            StudentSubjectProfile.student_profile_id == profile.id,
        ).order_by(StudentSubjectProfile.id))

    course_query = select(Course).where(Course.is_active.is_(True))
    paper_query = select(Paper).where(Paper.is_active.is_(True))
    if profile is not None:
        course_query = course_query.where(Course.grade == profile.grade)
        paper_query = paper_query.where(Paper.grade == profile.grade)
    if subject_profile is not None:
        course_query = course_query.where(Course.subject == subject_profile.subject)
        paper_query = paper_query.where(Paper.subject == subject_profile.subject)

    recommended_courses = list((await db.scalars(course_query.order_by(Course.id).limit(4))).all())
    if not recommended_courses:
        recommended_courses = list((await db.scalars(
            select(Course).where(Course.is_active.is_(True)).order_by(Course.id).limit(4)
        )).all())

    popular_courses = list((await db.scalars(
        select(Course).where(Course.is_active.is_(True)).order_by(Course.id).limit(4)
    )).all())
    latest_courses = list((await db.scalars(
        select(Course).where(Course.is_active.is_(True)).order_by(Course.created_at.desc(), Course.id.desc()).limit(4)
    )).all())
    papers = list((await db.scalars(paper_query.order_by(Paper.id).limit(4))).all())
    if not papers:
        papers = list((await db.scalars(
            select(Paper).where(Paper.is_active.is_(True)).order_by(Paper.id).limit(4)
        )).all())

    total_tasks = 0
    completed_tasks = 0
    today_total = 0
    today_completed = 0
    next_task = "暂无待完成任务"
    if profile is not None:
        week_start = date.today() - timedelta(days=date.today().weekday())
        week_end = week_start + timedelta(days=7)
        total_tasks, completed_tasks = (await db.execute(select(
            func.count(StudyTask.id),
            func.coalesce(func.sum(case((StudyTask.status == "已完成", 1), else_=0)), 0),
        ).where(
            StudyTask.student_profile_id == profile.id,
            StudyTask.scheduled_date >= week_start,
            StudyTask.scheduled_date < week_end,
        ))).one()
        today_total, today_completed = (await db.execute(select(
            func.count(StudyTask.id),
            func.coalesce(func.sum(case((StudyTask.status == "已完成", 1), else_=0)), 0),
        ).where(
            StudyTask.student_profile_id == profile.id,
            StudyTask.scheduled_date == date.today(),
        ))).one()
        pending_task = await db.scalar(select(StudyTask).where(
            StudyTask.student_profile_id == profile.id,
            StudyTask.status != "已完成",
        ).order_by(StudyTask.scheduled_date, StudyTask.id))
        if pending_task is not None:
            next_task = pending_task.name

    if subject_profile is not None:
        weak_points = subject_profile.weak_points or []
        reason = (
            f"结合最近成绩 {subject_profile.recent_score:g} 分"
            + (f"和薄弱知识点{'、'.join(weak_points[:2])}" if weak_points else "及当前学习目标")
            + "进行匹配"
        )
    else:
        weak_points = []
        reason = "根据当前年级和课程目录为你推荐"

    recommended = recommended_courses[0] if recommended_courses else None
    return ok({
        "studentProfileId": profile.id if profile is not None else 0,
        "banners": [
            {"id": 1, "title": "AI 智能选课", "subtitle": "结合成绩与薄弱点，推荐更合适的课程", "actionText": "立即咨询", "routeName": "AiAssistantPage", "imageKey": "AI"},
            {"id": 2, "title": "专项试卷训练", "subtitle": "按年级、学科和知识点精准练习", "actionText": "查看试卷", "routeName": "PaperResourcePage", "imageKey": "PAPER"},
            {"id": 3, "title": "本周学习计划", "subtitle": "拆分每日任务，让学习更有节奏", "actionText": "查看计划", "routeName": "StudyPlanPage", "imageKey": "PLAN"},
        ],
        "overview": {
            "studentBound": profile is not None,
            "studentName": profile.name if profile is not None else "",
            "grade": profile.grade if profile is not None else "",
            "subject": subject_profile.subject if subject_profile is not None else "",
            "recentScore": subject_profile.recent_score if subject_profile is not None else 0,
            "weakPoints": weak_points,
            "totalTasks": int(total_tasks or 0),
            "completedTasks": int(completed_tasks or 0),
        },
        "recommendedCourse": _course_data(recommended, 0, reason) if recommended is not None else {
            "id": 0, "name": "暂无匹配课程", "grade": "", "subject": "", "difficulty": "",
            "courseType": "", "priceText": "", "imageKey": "COURSE_1", "recommendReason": "请稍后重试",
        },
        "popularCourses": [_course_data(item, index) for index, item in enumerate(popular_courses)],
        "latestCourses": [_course_data(item, index + 2) for index, item in enumerate(latest_courses)],
        "recommendedPapers": [_paper_data(item, index) for index, item in enumerate(papers)],
        "todayTask": {
            "totalCount": int(today_total or 0),
            "completedCount": int(today_completed or 0),
            "nextTask": next_task,
        },
    })
