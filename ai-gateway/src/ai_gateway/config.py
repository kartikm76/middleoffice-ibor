from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

_PROJECT_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
            env_file=_PROJECT_ROOT / ".env",        # load variables from project .env
            env_prefix="",          # set to "" if you don't want a prefix
            extra="ignore",         # optional: ignore unknown env vars
    )
    structured_api_base: str = Field (
        default="http://localhost:8080/api",
        alias="STRUCTURED_API_BASE",   # <-- exact env var name
    )
    pg_dsn: str = Field(
        default="postgresql://ibor:ibor@localhost:5432/ibor",
        alias="PG_DSN",
    )
    openai_model: str = Field(
        default="gpt-4.1-mini",
        alias="OPENAI_MODEL",
    )
    openai_api_key: str = Field(
        default="",
        alias="OPENAI_API_KEY",
    )
    openai_embedding_model: str = Field(
        default="text-embedding-3-small",
        alias="OPENAI_EMBEDDING_MODEL",
    )

settings = Settings()