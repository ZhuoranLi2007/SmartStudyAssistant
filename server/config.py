from functools import lru_cache
import os
from pathlib import Path
import re

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


SERVER_DIR = Path(__file__).resolve().parent
COMMON_ENV_FILE = SERVER_DIR / ".env"


def _safe_environment_name(value: str | None) -> str:
    normalized = (value or "development").strip().lower()
    return normalized if re.fullmatch(r"[a-z0-9_-]+", normalized) else "development"


def _common_environment(path: Path = COMMON_ENV_FILE) -> str:
    if not path.exists():
        return "development"
    try:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key.strip() == "SMARTSTUDY_ENVIRONMENT":
                return _safe_environment_name(value.strip().strip("\"'"))
    except OSError:
        return "development"
    return "development"


def environment_files(environment: str | None = None, common_file: Path = COMMON_ENV_FILE) -> tuple[str, str]:
    selected = _safe_environment_name(
        environment or os.getenv("SMARTSTUDY_ENVIRONMENT") or _common_environment(common_file)
    )
    return str(common_file), str(common_file.with_name(f".env.{selected}"))


class Settings(BaseSettings):
    app_name: str = "SmartStudyAssistant API"
    environment: str = "development"
    database_url: str = "mysql+asyncmy://smartstudy:change-me@127.0.0.1:3306/smartstudy?charset=utf8mb4"
    jwt_secret: str = "change-this-secret-before-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 1440
    ai_provider: str = "deepseek"
    ai_enabled: bool = True
    ai_mock_fallback: bool = True
    ai_request_timeout: float = 30.0
    ai_max_history_messages: int = 20
    ai_temperature: float = 0.3
    deepseek_base_url: str = Field(
        default="https://api.deepseek.com",
        validation_alias=AliasChoices("SMARTSTUDY_DEEPSEEK_BASE_URL", "SMARTSTUDY_AI_BASE_URL"),
    )
    deepseek_api_key: str = Field(
        default="",
        validation_alias=AliasChoices("SMARTSTUDY_DEEPSEEK_API_KEY", "SMARTSTUDY_AI_API_KEY"),
    )
    deepseek_model: str = Field(
        default="deepseek-v4-flash",
        validation_alias=AliasChoices("SMARTSTUDY_DEEPSEEK_MODEL", "SMARTSTUDY_AI_MODEL"),
    )
    rag_top_k: int = 4
    log_level: str = "INFO"
    log_directory: Path = SERVER_DIR / "logs"
    log_max_bytes: int = 5 * 1024 * 1024
    log_backup_count: int = 5

    model_config = SettingsConfigDict(
        env_file=environment_files(),
        env_prefix="SMARTSTUDY_",
        extra="ignore",
    )

    @property
    def ai_base_url(self) -> str:
        return self.deepseek_base_url

    @property
    def ai_api_key(self) -> str:
        return self.deepseek_api_key

    @property
    def ai_model(self) -> str:
        return self.deepseek_model

    @property
    def max_chat_messages(self) -> int:
        return self.ai_max_history_messages


@lru_cache
def get_settings() -> Settings:
    return Settings()
