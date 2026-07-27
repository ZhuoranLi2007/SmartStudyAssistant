from collections import Counter
from datetime import date, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models import (
    Course,
    CourseEnrollment,
    Paper,
    PaperQuestion,
    PracticeAnswer,
    PracticeAttempt,
    StudentProfile,
    StudentSubjectProfile,
    StudyTask,
    User,
    WrongQuestion,
)
from server.services.access_service import ensure_student_access


FOUNDATION = "基础巩固型"
IMPROVEMENT = "中等提升型"
EXTENSION = "拔高拓展型"


def _calculate_level(score: float) -> str:
    if score < 60:
        return FOUNDATION
    if score < 80:
        return IMPROVEMENT
    return EXTENSION


def _match_by_weak_points(items: list, weak_points: list[str], limit: int | None = None):
    """按薄弱知识点顺序匹配，每个知识点优先返回一项；未传 limit 时返回所有匹配项。"""
    matched = []
    for point in weak_points:
        for item in items:
            if point in (getattr(item, "knowledge_points", None) or []) and item not in matched:
                matched.append(item)
                break
        if limit is not None and len(matched) >= limit:
            break
    return matched


def _prefer_level(items: list, level: str, points: list[str] | None = None, limit: int | None = None):
    """资源不足时把知识点和学习层次降为排序偏好；未传 limit 时返回所有项。"""
    target_points = points or []
    result = sorted(items, key=lambda item: (
        bool(target_points) and not any(point in (item.knowledge_points or []) for point in target_points),
        getattr(item, "level", None) != level
        and getattr(item, "suitable_course_level", None) != level,
        item.id,
    ))
    return result[:limit] if limit is not None else result


async def my_courses(db: AsyncSession, user: User, student_profile_id: int | None = None) -> list[dict]:
    statement = select(CourseEnrollment, Course).join(Course, Course.id == CourseEnrollment.course_id)
    if student_profile_id:
        await ensure_student_access(db, user, student_profile_id)
        statement = statement.where(CourseEnrollment.student_profile_id == student_profile_id)
    else:
        statement = statement.join(StudentProfile, StudentProfile.id == CourseEnrollment.student_profile_id)
        statement = statement.where(StudentProfile.student_user_id == user.id)
    rows = (await db.execute(statement.order_by(CourseEnrollment.updated_at.desc()))).all()
    return [{
        "id": enrollment.id,
        "courseId": course.id,
        "name": course.name,
        "grade": course.grade,
        "subject": course.subject,
        "completed": enrollment.status == "COMPLETED",
        "progress": {
            "completedLessons": enrollment.completed_lessons,
            "totalLessons": enrollment.total_lessons,
            "progress": enrollment.progress,
            "nextLesson": enrollment.next_lesson,
        },
    } for enrollment, course in rows]


async def submit_attempt(
    db: AsyncSession,
    user: User,
    student_profile_id: int,
    paper_id: int,
    answers: list[tuple[int, int]],
) -> dict:
    await ensure_student_access(db, user, student_profile_id)
    paper = await db.get(Paper, paper_id)
    if paper is None:
        raise HTTPException(status_code=404, detail="试卷不存在")
    question_ids = [item[0] for item in answers]
    if len(question_ids) != len(set(question_ids)):
        raise HTTPException(status_code=422, detail="同一道题不能重复提交")
    questions = list((await db.scalars(select(PaperQuestion).where(
        PaperQuestion.paper_id == paper_id,
        PaperQuestion.id.in_(question_ids),
    ))).all())
    if len(questions) != len(answers):
        raise HTTPException(status_code=422, detail="答案中包含无效题目")
    question_map = {item.id: item for item in questions}
    selected_map = dict(answers)
    correct_count = sum(1 for item in questions if selected_map[item.id] == item.correct_index)
    score = round(correct_count * 100 / len(questions), 1)
    knowledge_stats: dict[str, dict[str, int]] = {}
    attempt = PracticeAttempt(
        student_profile_id=student_profile_id,
        paper_id=paper_id,
        user_id=user.id,
        score=score,
        correct_count=correct_count,
        question_count=len(questions),
        knowledge_stats_json={},
    )
    db.add(attempt)
    await db.flush()
    for question_id, selected_index in answers:
        question = question_map[question_id]
        if selected_index >= len(question.options_json):
            raise HTTPException(status_code=422, detail="选项编号无效")
        correct = selected_index == question.correct_index
        stat = knowledge_stats.setdefault(question.knowledge_point, {"correct": 0, "total": 0})
        stat["total"] += 1
        if correct:
            stat["correct"] += 1
        db.add(PracticeAnswer(attempt_id=attempt.id, question_id=question.id, selected_index=selected_index, correct=correct))
        if not correct:
            wrong = await db.scalar(select(WrongQuestion).where(
                WrongQuestion.student_profile_id == student_profile_id,
                WrongQuestion.question_id == question.id,
            ))
            user_answer = question.options_json[selected_index]
            correct_answer = question.options_json[question.correct_index]
            if wrong is None:
                db.add(WrongQuestion(
                    student_profile_id=student_profile_id,
                    paper_id=paper_id,
                    question_id=question.id,
                    question_no=question.question_no,
                    subject=paper.subject,
                    knowledge_point=question.knowledge_point,
                    question_text=question.stem,
                    user_answer=user_answer,
                    correct_answer=correct_answer,
                    explanation=question.explanation,
                ))
            else:
                wrong.user_answer = user_answer
                wrong.correct_answer = correct_answer
                wrong.explanation = question.explanation
                wrong.question_no = question.question_no
                wrong.mastered = False
                wrong.wrong_count += 1
    attempt.knowledge_stats_json = knowledge_stats

    # 答卷提交是学习闭环的事实事件：保存成绩和错题后，再完成最近一条对应计划任务。
    task = await db.scalar(select(StudyTask).where(
        StudyTask.student_profile_id == student_profile_id,
        StudyTask.task_type == "试卷",
        StudyTask.target_id == paper_id,
        StudyTask.status != "已完成",
    ).order_by(StudyTask.created_at.desc()))
    if task is not None:
        task.status = "已完成"

    await db.flush()
    wrong_saved = len(questions) - correct_count
    return {
        "attemptId": attempt.id,
        "paperId": paper_id,
        "score": score,
        "correctCount": correct_count,
        "questionCount": len(questions),
        "wrongSavedCount": wrong_saved,
        "autoSavedToWrongBook": wrong_saved > 0,
        "knowledgeStats": knowledge_stats,
        "results": [{
            "questionId": item.id,
            "selectedIndex": selected_map[item.id],
            "correctIndex": item.correct_index,
            "correct": selected_map[item.id] == item.correct_index,
            "explanation": item.explanation,
        } for item in sorted(questions, key=lambda row: row.sequence)],
    }


async def add_wrong_questions_batch(
    db: AsyncSession, user: User, student_profile_id: int, items: list,
) -> dict:
    await ensure_student_access(db, user, student_profile_id)
    saved = 0
    for item in items:
        paper_id = int(getattr(item, "paper_id", 0) or 0)
        question_id = int(getattr(item, "question_id", 0) or 0)
        question_text = (getattr(item, "question_text", "") or "").strip()
        if not question_text:
            continue
        existing = None
        if question_id > 0:
            existing = await db.scalar(select(WrongQuestion).where(
                WrongQuestion.student_profile_id == student_profile_id,
                WrongQuestion.question_id == question_id,
            ))
        if existing is None:
            existing = await db.scalar(select(WrongQuestion).where(
                WrongQuestion.student_profile_id == student_profile_id,
                WrongQuestion.question_text == question_text,
            ))
        subject = (getattr(item, "subject", "") or "综合").strip() or "综合"
        knowledge_point = (getattr(item, "knowledge_point", "") or "综合").strip() or "综合"
        user_answer = getattr(item, "user_answer", "") or ""
        correct_answer = getattr(item, "correct_answer", "") or ""
        explanation = getattr(item, "explanation", "") or ""
        if existing is None:
            # 兼容旧客户端缺少 questionId 的批量数据，但错题外键仍必须绑定到真实题目。
            bind_question_id = question_id
            if bind_question_id <= 0:
                fallback = await db.scalar(select(PaperQuestion.id).where(
                    PaperQuestion.paper_id == paper_id
                ).order_by(PaperQuestion.sequence).limit(1)) if paper_id > 0 else None
                if fallback is None:
                    continue
                bind_question_id = int(fallback)
            if paper_id <= 0:
                paper_row = await db.get(PaperQuestion, bind_question_id)
                paper_id = paper_row.paper_id if paper_row is not None else 0
            if paper_id <= 0:
                continue
            paper_question = await db.get(PaperQuestion, bind_question_id)
            question_no = paper_question.question_no if paper_question is not None else 0
            db.add(WrongQuestion(
                student_profile_id=student_profile_id,
                paper_id=paper_id,
                question_id=bind_question_id,
                question_no=question_no,
                subject=subject,
                knowledge_point=knowledge_point,
                question_text=question_text,
                user_answer=user_answer,
                correct_answer=correct_answer,
                explanation=explanation,
            ))
            saved += 1
        else:
            existing.user_answer = user_answer
            existing.correct_answer = correct_answer
            existing.explanation = explanation
            existing.subject = subject
            existing.knowledge_point = knowledge_point
            existing.mastered = False
            existing.wrong_count += 1
            saved += 1
    await db.flush()
    return {"savedCount": saved}


async def wrong_question_list(db: AsyncSession, user: User, student_profile_id: int, subject: str | None = None) -> list[dict]:
    await ensure_student_access(db, user, student_profile_id)
    statement = select(WrongQuestion).where(WrongQuestion.student_profile_id == student_profile_id)
    if subject:
        statement = statement.where(WrongQuestion.subject == subject)
    rows = list((await db.scalars(statement.order_by(WrongQuestion.updated_at.desc()))).all())
    return [{
        "id": row.id,
        "questionNo": row.question_no,
        "subject": row.subject,
        "knowledgePoint": row.knowledge_point,
        "question": row.question_text,
        "userAnswer": row.user_answer,
        "correctAnswer": row.correct_answer,
        "explanation": row.explanation,
        "mastered": row.mastered,
        "wrongCount": row.wrong_count,
    } for row in rows]


async def wrong_question_training(
    db: AsyncSession, user: User, student_profile_id: int, wrong_question_id: int,
) -> dict:
    await ensure_student_access(db, user, student_profile_id)
    wrong = await db.get(WrongQuestion, wrong_question_id)
    if wrong is None or wrong.student_profile_id != student_profile_id:
        raise HTTPException(status_code=404, detail="错题不存在")
    question = await db.get(PaperQuestion, wrong.question_id)
    if question is None:
        raise HTTPException(status_code=404, detail="原题数据不存在")
    return {
        "id": wrong.id,
        "questionNo": wrong.question_no,
        "questionId": question.id,
        "subject": wrong.subject,
        "knowledgePoint": wrong.knowledge_point,
        "question": question.stem,
        "options": question.options_json,
        "previousAnswer": wrong.user_answer,
        "wrongCount": wrong.wrong_count,
        "mastered": wrong.mastered,
    }


async def submit_wrong_question_training(
    db: AsyncSession, user: User, student_profile_id: int, wrong_question_id: int, selected_index: int,
) -> dict:
    await ensure_student_access(db, user, student_profile_id)
    wrong = await db.get(WrongQuestion, wrong_question_id)
    if wrong is None or wrong.student_profile_id != student_profile_id:
        raise HTTPException(status_code=404, detail="错题不存在")
    question = await db.get(PaperQuestion, wrong.question_id)
    if question is None:
        raise HTTPException(status_code=404, detail="原题数据不存在")
    if selected_index < 0 or selected_index >= len(question.options_json):
        raise HTTPException(status_code=422, detail="选项编号无效")
    correct = selected_index == question.correct_index
    if correct:
        wrong.mastered = True
        tasks = list((await db.scalars(select(StudyTask).where(
            StudyTask.student_profile_id == student_profile_id,
            StudyTask.task_type == "错题",
            StudyTask.target_id == wrong_question_id,
        ))).all())
        for task in tasks:
            task.status = "已完成"
    else:
        wrong.mastered = False
        wrong.wrong_count += 1
        wrong.user_answer = question.options_json[selected_index]
    await db.flush()
    return {
        "correct": correct,
        "correctIndex": question.correct_index,
        "explanation": question.explanation or wrong.explanation,
        "mastered": wrong.mastered,
        "wrongCount": wrong.wrong_count,
    }


async def learning_report(db: AsyncSession, user: User, student_profile_id: int) -> dict:
    await ensure_student_access(db, user, student_profile_id)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=7)
    week_start_dt = datetime.combine(week_start, datetime.min.time())
    week_end_dt = datetime.combine(week_end, datetime.min.time())

    # 报告统一使用本地自然周：[周一 00:00, 下周一 00:00)，避免各指标时间口径不一致。
    completed_courses = await db.scalar(select(func.count(CourseEnrollment.id)).where(
        CourseEnrollment.student_profile_id == student_profile_id,
        CourseEnrollment.status == "COMPLETED",
        CourseEnrollment.updated_at >= week_start_dt,
        CourseEnrollment.updated_at < week_end_dt,
    )) or 0

    attempt_count, average_accuracy = (await db.execute(select(
        func.count(PracticeAttempt.id), func.coalesce(func.avg(PracticeAttempt.score), 0.0)
    ).where(
        PracticeAttempt.student_profile_id == student_profile_id,
        PracticeAttempt.submitted_at >= week_start_dt,
        PracticeAttempt.submitted_at < week_end_dt,
    ))).one()

    # 任务按计划日期统计，课程和错题按实际更新时间统计，分别反映计划执行与真实行为。
    task_count, completed_tasks = (await db.execute(select(
        func.count(StudyTask.id),
        func.coalesce(func.sum(case((StudyTask.status == "已完成", 1), else_=0)), 0),
    ).where(
        StudyTask.student_profile_id == student_profile_id,
        StudyTask.scheduled_date >= week_start,
        StudyTask.scheduled_date < week_end,
    ))).one()

    unresolved = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
        WrongQuestion.mastered.is_(False),
        WrongQuestion.updated_at >= week_start_dt,
        WrongQuestion.updated_at < week_end_dt,
    ))).all())

    mastered = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
        WrongQuestion.mastered.is_(True),
        WrongQuestion.updated_at >= week_start_dt,
        WrongQuestion.updated_at < week_end_dt,
    ))).all())

    weak_points = [name for name, _count in Counter(item.knowledge_point for item in unresolved).most_common(3)]
    improved_points = [name for name, _count in Counter(item.knowledge_point for item in mastered).most_common(3)]
    completion_rate = round(completed_tasks * 100 / task_count, 1) if task_count else 0.0

    suggestion = _build_ai_suggestion(
        completed_courses, int(attempt_count), round(float(average_accuracy), 1),
        completion_rate, weak_points, improved_points,
        int(task_count), int(completed_tasks),
    )

    return {
        "completedCourseCount": completed_courses,
        "completedPaperCount": int(attempt_count),
        "averageAccuracy": round(float(average_accuracy), 1),
        "taskCompletionRate": completion_rate,
        "improvedPoints": improved_points,
        "weakPoints": weak_points,
        "aiSuggestion": suggestion,
    }


def _build_ai_suggestion(
    completed_courses: int,
    completed_papers: int,
    avg_accuracy: float,
    task_rate: float,
    weak_points: list[str],
    improved_points: list[str],
    total_tasks: int,
    completed_tasks: int,
) -> str:
    parts: list[str] = []

    if task_rate >= 80:
        parts.append("本周任务完成情况很好，学习节奏稳定。")
    elif task_rate >= 50:
        parts.append("本周任务完成过半，继续保持这个节奏会看到明显进步。")
    else:
        parts.append(f"本周任务完成率偏低（{task_rate:.0f}%），建议下周优先补齐未完成的 {total_tasks - completed_tasks} 项任务。")

    if completed_papers > 0:
        parts.append(f"本周完成 {completed_papers} 套试卷，平均正确率 {avg_accuracy:.1f}%。")
        if avg_accuracy >= 85:
            parts.append("整体答题状态不错，重点知识点掌握较好。")
        elif avg_accuracy >= 60:
            parts.append("还有提升空间，建议把错题对应的知识点加入下周复习计划。")
        else:
            parts.append("正确率较低，建议从薄弱知识点的基础题目开始专项训练。")
    else:
        parts.append("本周还没有完成试卷练习，建议安排至少一套试卷检测学习效果。")

    if completed_courses > 0:
        parts.append(f"本周完成 {completed_courses} 门课程学习。")
    else:
        parts.append("本周课程学习进度较少，建议按学习计划推进课程内容。")

    if weak_points:
        parts.append(f"下周可重点突破：{'、'.join(weak_points)}。")
    if improved_points:
        parts.append(f"近期掌握较好的知识点：{'、'.join(improved_points)}，可以适当巩固后进入下一专题。")

    if not weak_points and not improved_points:
        parts.append("本周暂无错题记录，建议多做练习以生成更精准的学习建议。")

    return "".join(parts)


async def generate_week_plan(db: AsyncSession, user: User, student_profile_id: int, session_id: str | None) -> dict:
    profile = await ensure_student_access(db, user, student_profile_id)
    subject_profile = await db.scalar(select(StudentSubjectProfile).where(
        StudentSubjectProfile.student_profile_id == student_profile_id
    ).order_by(StudentSubjectProfile.updated_at.desc()))
    if subject_profile is None:
        raise HTTPException(status_code=404, detail="未找到学科档案，请先完善学生档案")

    subject = subject_profile.subject
    weak_points = subject_profile.weak_points or [f"{subject}基础知识"]
    score = subject_profile.recent_score
    level = _calculate_level(score)
    # 每日时长由周预算均分，并限制在适合单次学习的 20～90 分钟。
    duration = max(20, min(90, profile.weekly_study_minutes // 7))

    exact_courses = list((await db.scalars(select(Course).where(
        Course.grade == profile.grade, Course.subject == subject,
        Course.level == level, Course.is_active.is_(True)
    ).order_by(Course.id))).all())
    course_rows = _match_by_weak_points(exact_courses, weak_points) if weak_points else exact_courses
    if not course_rows:
        same_grade_courses = list((await db.scalars(select(Course).where(
            Course.grade == profile.grade,
            Course.subject == subject,
            Course.is_active.is_(True),
        ).order_by(Course.id))).all())
        course_rows = _prefer_level(same_grade_courses, level, weak_points)
    if not course_rows:
        same_subject_courses = list((await db.scalars(select(Course).where(
            Course.subject == subject,
            Course.is_active.is_(True),
        ).order_by(Course.id))).all())
        course_rows = _prefer_level(same_subject_courses, level, weak_points)

    exact_papers = list((await db.scalars(select(Paper).where(
        Paper.grade == profile.grade, Paper.subject == subject,
        Paper.suitable_course_level == level, Paper.is_active.is_(True),
        Paper.is_ai_generated.is_(False)
    ).order_by(Paper.id))).all())
    paper_rows = _match_by_weak_points(exact_papers, weak_points) if weak_points else exact_papers
    if not paper_rows:
        same_grade_papers = list((await db.scalars(select(Paper).where(
            Paper.grade == profile.grade,
            Paper.subject == subject,
            Paper.is_active.is_(True),
            Paper.is_ai_generated.is_(False),
        ).order_by(Paper.id))).all())
        paper_rows = _prefer_level(same_grade_papers, level, weak_points)
    if not paper_rows:
        same_subject_papers = list((await db.scalars(select(Paper).where(
            Paper.subject == subject,
            Paper.is_active.is_(True),
            Paper.is_ai_generated.is_(False),
        ).order_by(Paper.id))).all())
        paper_rows = _prefer_level(same_subject_papers, level, weak_points)

    # 错题本里只要有错题就安排复测，不区分是否已掌握
    wrong_questions = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
    ).order_by(WrongQuestion.wrong_count.desc(), WrongQuestion.updated_at.desc()))).all())

    course_index = 0
    paper_index = 0
    wrong_added = False

    def next_course() -> Course | None:
        nonlocal course_index
        if course_index >= len(course_rows):
            return None
        course = course_rows[course_index]
        course_index += 1
        return course

    def next_paper() -> Paper | None:
        nonlocal paper_index
        if paper_index >= len(paper_rows):
            return None
        paper = paper_rows[paper_index]
        paper_index += 1
        return paper

    def build_course_task(day_index: int) -> dict | None:
        course = next_course()
        if course is None:
            return None
        return {
            "id": -(day_index + 1),
            "date": (date.today() + timedelta(days=day_index)).isoformat(),
            "title": course.name,
            "taskType": "课程",
            "durationMinutes": min(60, duration + 15),
            "courseId": course.id,
            "paperId": None,
            "wrongQuestionId": None,
            "knowledgePoint": (course.knowledge_points or [subject])[0],
            "status": "未开始",
        }

    def build_paper_task(day_index: int) -> dict | None:
        paper = next_paper()
        if paper is None:
            return None
        return {
            "id": -(day_index + 1),
            "date": (date.today() + timedelta(days=day_index)).isoformat(),
            "title": paper.name,
            "taskType": "试卷",
            "durationMinutes": 40,
            "courseId": None,
            "paperId": paper.id,
            "wrongQuestionId": None,
            "knowledgePoint": (paper.knowledge_points or [subject])[0],
            "status": "未开始",
        }

    def build_wrong_task(day_index: int) -> dict | None:
        if not wrong_questions:
            return None
        return {
            "id": -(day_index + 1),
            "date": (date.today() + timedelta(days=day_index)).isoformat(),
            "title": "错题复测",
            "taskType": "错题",
            "durationMinutes": 15 * len(wrong_questions),
            "courseId": None,
            "paperId": None,
            "wrongQuestionId": 0,
            "knowledgePoint": "错题复盘",
            "status": "未开始",
        }

    # 按真实日期连续 7 天，顺序填充：课程、试卷、课程、试卷、错题复测、课程、试卷。
    # 错题复测只出现一次，包含所有未掌握错题；后续若再次轮到错题则跳过。
    base_types = ["课程", "试卷", "课程", "试卷", "错题", "课程", "试卷"]

    def build_task(task_type: str, day_index: int) -> dict | None:
        nonlocal wrong_added
        if task_type == "课程":
            return build_course_task(day_index)
        if task_type == "试卷":
            return build_paper_task(day_index)
        if wrong_added:
            return None
        task = build_wrong_task(day_index)
        if task is not None:
            wrong_added = True
        return task

    tasks: list[dict] = []
    for index in range(7):
        task = build_task(base_types[index], index)
        if task is None:
            for fallback_type in ["课程", "试卷"]:
                task = build_task(fallback_type, index)
                if task is not None:
                    break
        if task is not None:
            tasks.append(task)

    if not tasks:
        raise HTTPException(status_code=404, detail="未找到匹配的学习资源，请完善课程或试卷数据")

    # 负任务 ID 和 planId=0 明确表示预览，避免前端把 AI 建议误认为已落库任务。
    return {
        "planId": 0,
        "title": f"{profile.name}的一周学习计划",
        "taskCount": len(tasks),
        "tasks": tasks,
    }
