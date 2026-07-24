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
from server.services.recommendation_service import calculate_level


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

    # 同步将学习计划中对应的未完成的试卷任务标记为已完成
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
            # question_id 有外键时必须落到真实题目；否则尽量绑定试卷第一题避免失败
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

    # 本周完成课程（状态为 COMPLETED 且本周有更新）
    completed_courses = await db.scalar(select(func.count(CourseEnrollment.id)).where(
        CourseEnrollment.student_profile_id == student_profile_id,
        CourseEnrollment.status == "COMPLETED",
        CourseEnrollment.updated_at >= week_start_dt,
        CourseEnrollment.updated_at < week_end_dt,
    )) or 0

    # 本周完成试卷与平均正确率
    attempt_count, average_accuracy = (await db.execute(select(
        func.count(PracticeAttempt.id), func.coalesce(func.avg(PracticeAttempt.score), 0.0)
    ).where(
        PracticeAttempt.student_profile_id == student_profile_id,
        PracticeAttempt.submitted_at >= week_start_dt,
        PracticeAttempt.submitted_at < week_end_dt,
    ))).one()

    # 本周学习任务完成率（按本周计划日期统计，与学习计划页区分：报告聚焦本周执行结果）
    task_count, completed_tasks = (await db.execute(select(
        func.count(StudyTask.id),
        func.coalesce(func.sum(case((StudyTask.status == "已完成", 1), else_=0)), 0),
    ).where(
        StudyTask.student_profile_id == student_profile_id,
        StudyTask.scheduled_date >= week_start,
        StudyTask.scheduled_date < week_end,
    ))).one()

    # 本周薄弱知识点（未掌握且本周有更新的错题）
    unresolved = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
        WrongQuestion.mastered.is_(False),
        WrongQuestion.updated_at >= week_start_dt,
        WrongQuestion.updated_at < week_end_dt,
    ))).all())

    # 本周进步知识点（已掌握且本周有更新的错题）
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
    if session_id:
        existing_tasks = list((await db.scalars(select(StudyTask).where(
            StudyTask.student_profile_id == student_profile_id,
            StudyTask.source_session_id == session_id,
        ).order_by(StudyTask.scheduled_date, StudyTask.id))).all())
        if existing_tasks:
            return {
                "planId": existing_tasks[0].id,
                "title": f"{profile.name}的一周学习计划",
                "taskCount": len(existing_tasks),
                "tasks": [{
                    "id": item.id,
                    "date": item.scheduled_date.isoformat() if item.scheduled_date else "",
                    "title": item.name,
                    "taskType": item.task_type,
                    "durationMinutes": item.duration_minutes,
                    "courseId": item.target_id if item.task_type == "课程" else None,
                    "paperId": item.target_id if item.task_type == "试卷" else None,
                    "knowledgePoint": item.knowledge_point,
                    "status": item.status,
                } for item in existing_tasks],
            }
    subject_profile = await db.scalar(select(StudentSubjectProfile).where(
        StudentSubjectProfile.student_profile_id == student_profile_id
    ).order_by(StudentSubjectProfile.updated_at.desc()))
    if subject_profile is None:
        raise HTTPException(status_code=404, detail="未找到学科档案，请先完善学生档案")

    level = calculate_level(subject_profile.recent_score)
    weak_points = subject_profile.weak_points or []
    subject = subject_profile.subject

    all_courses = list((await db.scalars(select(Course).where(
        Course.grade == profile.grade, Course.subject == subject,
        Course.level == level, Course.is_active.is_(True)
    ))).all())
    matched_courses = []
    for point in weak_points:
        for course in all_courses:
            if point in (course.knowledge_points or []) and course not in matched_courses:
                matched_courses.append(course)
                break
    courses = matched_courses if matched_courses else all_courses[:4]

    all_papers = list((await db.scalars(select(Paper).where(
        Paper.grade == profile.grade, Paper.subject == subject,
        Paper.suitable_course_level == level, Paper.is_active.is_(True)
    ))).all())
    matched_papers = []
    for point in weak_points:
        for paper in all_papers:
            if point in (paper.knowledge_points or []) and paper not in matched_papers:
                matched_papers.append(paper)
                break
    papers = matched_papers if matched_papers else all_papers[:4]

    if not courses and not papers:
        raise HTTPException(status_code=404, detail="暂无可生成计划的课程或试卷")
    duration = max(20, min(90, profile.weekly_study_minutes // 7))
    tasks: list[StudyTask] = []
    for index in range(7):
        use_course = index % 2 == 0 and courses
        target = courses[index % len(courses)] if use_course else papers[index % len(papers)] if papers else courses[index % len(courses)]
        task_type = "课程" if isinstance(target, Course) else "试卷"
        task = StudyTask(
            student_profile_id=student_profile_id,
            creator_user_id=user.id,
            task_type=task_type,
            target_id=target.id,
            name=target.name,
            subject=target.subject,
            difficulty=target.difficulty,
            scheduled_date=date.today() + timedelta(days=index),
            duration_minutes=duration,
            knowledge_point=(target.knowledge_points or [""])[0],
            source_session_id=session_id,
        )
        db.add(task)
        tasks.append(task)
    await db.flush()
    return {
        "planId": tasks[0].id,
        "title": f"{profile.name}的一周学习计划",
        "taskCount": len(tasks),
        "tasks": [{
            "id": item.id,
            "date": item.scheduled_date.isoformat(),
            "title": item.name,
            "taskType": item.task_type,
            "durationMinutes": item.duration_minutes,
            "courseId": item.target_id if item.task_type == "课程" else None,
            "paperId": item.target_id if item.task_type == "试卷" else None,
            "knowledgePoint": item.knowledge_point,
            "status": item.status,
        } for item in tasks],
    }
