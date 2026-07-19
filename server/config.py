from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


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

    model_config = SettingsConfigDict(env_file="server/.env", env_prefix="SMARTSTUDY_", extra="ignore")

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
