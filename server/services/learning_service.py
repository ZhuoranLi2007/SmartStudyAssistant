from collections import Counter
from datetime import date, timedelta

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
    StudyTask,
    User,
    WrongQuestion,
)
from server.services.access_service import ensure_student_access


async def my_courses(db: AsyncSession, user: User, student_profile_id: int | None = None) -> list[dict]:
    statement = select(CourseEnrollment, Course).join(Course, Course.id == CourseEnrollment.course_id)
    if student_profile_id:
        await ensure_student_access(db, user, student_profile_id)
        statement = statement.where(CourseEnrollment.student_profile_id == student_profile_id)
    else:
        statement = statement.join(StudentProfile, StudentProfile.id == CourseEnrollment.student_profile_id)
        if user.role == "student":
            statement = statement.where(StudentProfile.student_user_id == user.id)
        else:
            from server.models import FamilyMember
            statement = statement.join(FamilyMember, FamilyMember.family_id == StudentProfile.family_id).where(FamilyMember.user_id == user.id)
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
                wrong.mastered = False
                wrong.wrong_count += 1
    attempt.knowledge_stats_json = knowledge_stats
    await db.flush()
    return {
        "attemptId": attempt.id,
        "paperId": paper_id,
        "score": score,
        "correctCount": correct_count,
        "questionCount": len(questions),
        "knowledgeStats": knowledge_stats,
        "results": [{
            "questionId": item.id,
            "selectedIndex": selected_map[item.id],
            "correctIndex": item.correct_index,
            "correct": selected_map[item.id] == item.correct_index,
            "explanation": item.explanation,
        } for item in sorted(questions, key=lambda row: row.sequence)],
    }


async def wrong_question_list(db: AsyncSession, user: User, student_profile_id: int, subject: str | None = None) -> list[dict]:
    await ensure_student_access(db, user, student_profile_id)
    statement = select(WrongQuestion).where(WrongQuestion.student_profile_id == student_profile_id)
    if subject:
        statement = statement.where(WrongQuestion.subject == subject)
    rows = list((await db.scalars(statement.order_by(WrongQuestion.updated_at.desc()))).all())
    return [{
        "id": row.id,
        "subject": row.subject,
        "knowledgePoint": row.knowledge_point,
        "question": row.question_text,
        "userAnswer": row.user_answer,
        "correctAnswer": row.correct_answer,
        "explanation": row.explanation,
        "mastered": row.mastered,
        "wrongCount": row.wrong_count,
    } for row in rows]


async def learning_report(db: AsyncSession, user: User, student_profile_id: int) -> dict:
    await ensure_student_access(db, user, student_profile_id)
    completed_courses = await db.scalar(select(func.count(CourseEnrollment.id)).where(
        CourseEnrollment.student_profile_id == student_profile_id,
        CourseEnrollment.status == "COMPLETED",
    )) or 0
    attempt_count, average_accuracy = (await db.execute(select(
        func.count(PracticeAttempt.id), func.coalesce(func.avg(PracticeAttempt.score), 0.0)
    ).where(PracticeAttempt.student_profile_id == student_profile_id))).one()
    task_count, completed_tasks = (await db.execute(select(
        func.count(StudyTask.id),
        func.coalesce(func.sum(case((StudyTask.status == "已完成", 1), else_=0)), 0),
    ).where(StudyTask.student_profile_id == student_profile_id))).one()
    unresolved = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
        WrongQuestion.mastered.is_(False),
    ))).all())
    mastered = list((await db.scalars(select(WrongQuestion).where(
        WrongQuestion.student_profile_id == student_profile_id,
        WrongQuestion.mastered.is_(True),
    ))).all())
    weak_points = [name for name, _count in Counter(item.knowledge_point for item in unresolved).most_common(3)]
    improved_points = [name for name, _count in Counter(item.knowledge_point for item in mastered).most_common(3)]
    completion_rate = round(completed_tasks * 100 / task_count, 1) if task_count else 0.0
    suggestion = "建议保持当前学习节奏，每周完成一次复盘。"
    if weak_points:
        suggestion = f"下周优先复习{'、'.join(weak_points)}，完成专项训练后再进行一次复测。"
    return {
        "completedCourseCount": completed_courses,
        "completedPaperCount": attempt_count,
        "averageAccuracy": round(float(average_accuracy), 1),
        "taskCompletionRate": completion_rate,
        "improvedPoints": improved_points,
        "weakPoints": weak_points,
        "aiSuggestion": suggestion,
    }


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
    courses = list((await db.scalars(select(Course).where(Course.grade == profile.grade, Course.is_active.is_(True)).limit(4))).all())
    papers = list((await db.scalars(select(Paper).where(Paper.grade == profile.grade, Paper.is_active.is_(True)).limit(4))).all())
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
