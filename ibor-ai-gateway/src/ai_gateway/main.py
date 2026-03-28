from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from anthropic import AsyncAnthropic

from ai_gateway.service.embedding_provider import EmbeddingProvider

from ai_gateway.config.settings import settings
from ai_gateway.config.db import PgPool, PgPoolConfig
from ai_gateway.repository.ibor_repository import IborRepository
from ai_gateway.service.ibor_service import IborService
from ai_gateway.service.llm_service import LlmService
from ai_gateway.service.market_tools import MarketTools
from ai_gateway.service.conversation_service import ConversationService
from ai_gateway.service.embedding_scheduler import EmbeddingScheduler
from ai_gateway.controller.health import router as health_router
from ai_gateway.controller.analyst import make_analyst_router
from ai_gateway.controller import conversation_test
from ai_gateway.controller import scheduler_test
from ai_gateway.infra.security_middleware import SecurityMiddleware, InputValidationMiddleware, QuotaCheckMiddleware


def create_app() -> FastAPI:
    if not settings.anthropic_api_key:
        raise RuntimeError("ANTHROPIC_API_KEY is not configured. Check ai-gateway/.env.")

    # Initialize repositories and services
    ibor_repository = IborRepository(base_url=settings.structured_api_base)
    service = IborService(client=ibor_repository)
    anthropic_client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    embedding_provider = EmbeddingProvider()  # Local embeddings (no API key needed)
    market_tools = MarketTools()

    # Initialize database pool and conversation service
    pg_config = PgPoolConfig(dsn=settings.pg_dsn)
    pg_pool = PgPool(pg_config)
    conversation_service = ConversationService(pg_pool, anthropic_client, embedding_provider)

    llm_service = LlmService(
        anthropic_client=anthropic_client,
        service=service,
        market_tools=market_tools,
        model=settings.anthropic_model,
    )

    # Initialize embedding scheduler
    embedding_scheduler = EmbeddingScheduler(conversation_service, pg_pool)

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        # Startup
        await embedding_scheduler.start()
        yield
        # Shutdown
        await embedding_scheduler.stop()
        await ibor_repository.aclose()
        pg_pool.close()

    app = FastAPI(title="IBOR AI Gateway", version="0.2.0", lifespan=lifespan)

    # Security middlewares (added in reverse order — they execute top-to-bottom)
    app.add_middleware(QuotaCheckMiddleware)
    app.add_middleware(InputValidationMiddleware)
    app.add_middleware(SecurityMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:4200", "http://localhost:5173", "localhost", "127.0.0.1"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Wire conversation service to test controller and analyst router
    conversation_test.conversation_service = conversation_service
    scheduler_test.scheduler = embedding_scheduler

    app.include_router(health_router, tags=["health"])
    app.include_router(make_analyst_router(service, llm_service, conversation_service))
    app.include_router(conversation_test.router)
    app.include_router(scheduler_test.router)

    @app.get("/", include_in_schema=False)
    def root():
        return {
            "service": "ibor-ai-gateway",
            "version": "0.2.0",
            "links": {"health": "/health", "docs": "/docs", "chat": "/analyst/chat"},
        }

    return app


app = create_app()
