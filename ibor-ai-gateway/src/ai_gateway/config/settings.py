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

    # ─────────────────────────────────────────────────────────────────────────
    # Security: Rate Limiting, Quotas, Cost Controls, Authentication
    # ─────────────────────────────────────────────────────────────────────────

    # Phase 1: Closed Beta (email whitelist + shared API key)
    environment: str = os.getenv("ENVIRONMENT", "development")  # development, beta, production

    # 1. RATE LIMITING — per IP per minute
    rate_limit_requests_per_minute: int = int(os.getenv("RATE_LIMIT_RPM", "30"))
    rate_limit_enabled: bool = os.getenv("RATE_LIMIT_ENABLED", "false").lower() == "true"

    # 2. AUTHENTICATION — Email whitelist for closed beta
    email_whitelist_enabled: bool = os.getenv("EMAIL_WHITELIST_ENABLED", "false").lower() == "true"
    email_whitelist: list[str] = os.getenv("EMAIL_WHITELIST", "").split(",") if os.getenv("EMAIL_WHITELIST") else []

    # 3. QUOTAS — Daily usage limits
    max_questions_per_day: int = int(os.getenv("MAX_QUESTIONS_PER_DAY", "100"))
    max_tokens_per_day: int = int(os.getenv("MAX_TOKENS_PER_DAY", "500000"))

    # 4. COST CONTROLS — OpenAI API spending limits
    max_daily_spend_usd: float = float(os.getenv("MAX_DAILY_SPEND_USD", "50.0"))
    cost_tracking_enabled: bool = os.getenv("COST_TRACKING_ENABLED", "false").lower() == "true"

    # 5. INPUT VALIDATION
    max_question_length: int = int(os.getenv("MAX_QUESTION_LENGTH", "2000"))
    min_question_length: int = int(os.getenv("MIN_QUESTION_LENGTH", "10"))
    banned_keywords: list[str] = os.getenv("BANNED_KEYWORDS", "").split(",") if os.getenv("BANNED_KEYWORDS") else []

    # 6. MONITORING & LOGGING
    log_all_requests: bool = os.getenv("LOG_ALL_REQUESTS", "true").lower() == "true"
    alert_on_quota_violation: bool = os.getenv("ALERT_ON_QUOTA_VIOLATION", "true").lower() == "true"


settings = Settings()
