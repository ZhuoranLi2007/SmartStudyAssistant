from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SmartStudyAssistant API"
    environment: str = "development"
    database_url: str = "sqlite+aiosqlite:///./server/smartstudy.db"
    jwt_secret: str = "change-this-secret-before-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 1440
    ai_provider: str = "mock"
    ai_base_url: str = "https://api.deepseek.com"
    ai_api_key: str = ""
    ai_model: str = "deepseek-chat"
    max_chat_messages: int = 20

    model_config = SettingsConfigDict(env_file="server/.env", env_prefix="SMARTSTUDY_", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
