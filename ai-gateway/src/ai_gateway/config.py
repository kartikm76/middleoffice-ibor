from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    structured_api_base: str = "http://localhost:8080/api",
    openai_model: str = "gpt-4.1-mini"

    # Pydantic v2: use SettingsConfigDict instead of inner Config class
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="AI_GATEWAY_",
        extra="ignore",  # ignore unknown env vars instead of failing        
    )

settings = Settings()