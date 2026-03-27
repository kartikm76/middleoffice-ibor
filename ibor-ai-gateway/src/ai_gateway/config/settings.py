from __future__ import annotations

import os
from pathlib import Path

import yaml
from dotenv import load_dotenv

_root = Path(__file__).resolve().parents[3]  # ai-gateway/
load_dotenv(_root / ".env")

with open(_root / "config.yaml") as f:
    _cfg = yaml.safe_load(f)


class Settings:
    """Loads non-secret settings from config.yaml.
    Secrets (ANTHROPIC_API_KEY, PG_DSN) must be set via environment variables or .env file.
    Environment variables override config.yaml values for all fields.
    """
    structured_api_base: str    = os.getenv("STRUCTURED_API_BASE", _cfg["ibor"]["api_base"])
    verify_ssl: bool             = os.getenv("VERIFY_SSL", str(_cfg["ibor"]["verify_ssl"])).lower() == "true"
    anthropic_model: str         = os.getenv("ANTHROPIC_MODEL", _cfg["llm"]["primary"]["name"])
    openai_embedding_model: str  = os.getenv("OPENAI_EMBEDDING_MODEL", _cfg["embeddings"]["primary"]["name"])
    pg_dsn: str                  = os.getenv("PG_DSN", _cfg["database"]["dsn"])
    anthropic_api_key: str       = os.getenv("ANTHROPIC_API_KEY", "")
    openai_api_key: str          = os.getenv("OPENAI_API_KEY", "")  # still used for RAG embeddings


settings = Settings()
