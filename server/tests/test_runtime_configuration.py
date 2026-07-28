import logging
from pathlib import Path

import pytest

from server.config import Settings, environment_files
from server.logging_config import configure_logging


def test_environment_files_default_and_explicit_selection(tmp_path, monkeypatch):
    common_file = tmp_path / ".env"
    common_file.write_text("SMARTSTUDY_ENVIRONMENT=production\n", encoding="utf-8")
    monkeypatch.delenv("SMARTSTUDY_ENVIRONMENT", raising=False)

    assert environment_files(common_file=common_file) == (
        str(common_file), str(tmp_path / ".env.production"),
    )
    assert environment_files("development", common_file) == (
        str(common_file), str(tmp_path / ".env.development"),
    )


def test_environment_specific_file_and_process_environment_precedence(tmp_path, monkeypatch):
    common_file = tmp_path / ".env"
    development_file = tmp_path / ".env.development"
    common_file.write_text(
        "SMARTSTUDY_ENVIRONMENT=development\nSMARTSTUDY_LOG_LEVEL=INFO\n",
        encoding="utf-8",
    )
    development_file.write_text("SMARTSTUDY_LOG_LEVEL=DEBUG\n", encoding="utf-8")
    monkeypatch.delenv("SMARTSTUDY_LOG_LEVEL", raising=False)

    files = environment_files(common_file=common_file)
    assert Settings(_env_file=files).log_level == "DEBUG"
    monkeypatch.setenv("SMARTSTUDY_LOG_LEVEL", "WARNING")
    assert Settings(_env_file=files).log_level == "WARNING"


@pytest.mark.asyncio
async def test_request_log_is_persisted_without_authorization_header(client, tmp_path):
    settings = Settings(
        log_directory=tmp_path,
        log_level="INFO",
        log_max_bytes=1024,
        log_backup_count=1,
    )
    log_path = configure_logging(settings)
    secret = "Bearer test-token-must-not-be-logged"
    try:
        response = await client.get("/api/health", headers={"Authorization": secret})
        assert response.status_code == 200
        for handler in logging.getLogger().handlers:
            handler.flush()
        content = log_path.read_text(encoding="utf-8")
        assert "GET /api/health 200" in content
        assert secret not in content
    finally:
        configure_logging(Settings())


def test_log_file_rotates(tmp_path):
    settings = Settings(
        log_directory=tmp_path,
        log_level="INFO",
        log_max_bytes=1024,
        log_backup_count=1,
    )
    log_path = configure_logging(settings)
    try:
        logger = logging.getLogger("smartstudy.rotation-test")
        for index in range(40):
            logger.info("rotation-line-%s %s", index, "x" * 80)
        for handler in logging.getLogger().handlers:
            handler.flush()
        assert log_path.exists()
        assert (tmp_path / "smartstudy.log.1").exists()
    finally:
        configure_logging(Settings())
