import logging

from sqlalchemy import text

from server.database import engine

logger = logging.getLogger("smartstudy.schema")


async def _ensure_favorites_table() -> None:
    try:
        async with engine.begin() as connection:
            result = await connection.execute(text(
                "SELECT COUNT(*) FROM information_schema.COLUMNS "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'favorites' AND COLUMN_NAME = 'type'"
            ))
            if int(result.scalar() or 0) > 0:
                return
            await connection.execute(text("DROP TABLE IF EXISTS favorites"))
            await connection.execute(text("""
                CREATE TABLE favorites (
                    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                    student_profile_id INT NOT NULL,
                    target_id INT NOT NULL,
                    type VARCHAR(20) NOT NULL,
                    title VARCHAR(150) NOT NULL,
                    subtitle VARCHAR(150) NOT NULL DEFAULT '',
                    tag VARCHAR(50) NOT NULL DEFAULT '',
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    UNIQUE KEY uq_student_favorite (student_profile_id, target_id, type),
                    KEY ix_favorites_student_profile_id (student_profile_id),
                    KEY ix_favorites_target_id (target_id),
                    KEY ix_favorites_type (type),
                    CONSTRAINT fk_favorites_student FOREIGN KEY (student_profile_id)
                        REFERENCES student_profiles(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """))
            logger.info("favorites 表已按最新结构重建")
    except Exception as exc:
        logger.info("favorites schema ensure skipped: %s", exc)


async def ensure_schema_patches() -> None:
    # 这些补丁只服务于早期演示库的平滑升级；正式版本仍以 Alembic 迁移为准。
    patches = [
        "ALTER TABLE course_enrollments MODIFY COLUMN order_id INT NULL",
        "ALTER TABLE student_profiles ADD COLUMN profile_completed TINYINT(1) NOT NULL DEFAULT 0",
        "ALTER TABLE paper_questions ADD COLUMN question_no INT NULL",
        "ALTER TABLE wrong_questions ADD COLUMN question_no INT NOT NULL DEFAULT 0",
        "ALTER TABLE paper_questions ADD UNIQUE KEY uq_paper_question_no (question_no)",
        "ALTER TABLE papers ADD COLUMN is_ai_generated TINYINT(1) NOT NULL DEFAULT 0",
        "ALTER TABLE papers ADD COLUMN created_by INT NULL",
        "ALTER TABLE papers ADD KEY ix_papers_created_by (created_by)",
    ]
    for sql in patches:
        try:
            async with engine.begin() as connection:
                await connection.execute(text(sql))
        except Exception as exc:
            logger.info("schema patch skipped or already applied: %s", exc)

    try:
        async with engine.begin() as connection:
            await connection.execute(text("""
                UPDATE wrong_questions wq
                JOIN paper_questions pq ON wq.question_id = pq.id
                SET wq.question_no = pq.question_no
                WHERE pq.question_no > 0 AND wq.question_no = 0
            """))
    except Exception as exc:
        logger.info("wrong_questions question_no repair skipped: %s", exc)
    await _ensure_favorites_table()
