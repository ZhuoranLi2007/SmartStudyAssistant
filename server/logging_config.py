import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

from server.config import Settings


FORMAT = "%(asctime)s %(levelname)s %(name)s %(message)s"
CONSOLE_HANDLER_NAME = "smartstudy.console"
FILE_HANDLER_NAME = "smartstudy.file"


def _remove_handler(logger: logging.Logger, name: str) -> None:
    for handler in list(logger.handlers):
        if handler.get_name() == name:
            logger.removeHandler(handler)
            handler.close()


def configure_logging(settings: Settings) -> Path:
    level = getattr(logging, settings.log_level.upper(), logging.INFO)
    formatter = logging.Formatter(FORMAT)
    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Reconfiguration is intentional for tests and Uvicorn reloads; unrelated handlers are preserved.
    _remove_handler(root_logger, CONSOLE_HANDLER_NAME)
    _remove_handler(root_logger, FILE_HANDLER_NAME)

    console_handler = logging.StreamHandler()
    console_handler.set_name(CONSOLE_HANDLER_NAME)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    log_directory = Path(settings.log_directory)
    log_directory.mkdir(parents=True, exist_ok=True)
    log_path = log_directory / "smartstudy.log"
    file_handler = RotatingFileHandler(
        log_path,
        maxBytes=max(1024, settings.log_max_bytes),
        backupCount=max(1, settings.log_backup_count),
        encoding="utf-8",
    )
    file_handler.set_name(FILE_HANDLER_NAME)
    file_handler.setLevel(level)
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)
    return log_path
