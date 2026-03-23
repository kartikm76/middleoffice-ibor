from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from anthropic import AsyncAnthropic

from ai_gateway.config.settings import settings
from ai_gateway.repository.ibor_repository import IborRepository
from ai_gateway.service.ibor_service import IborService
from ai_gateway.service.llm_service import LlmService
from ai_gateway.service.market_tools import MarketTools
from ai_gateway.controller.health import router as health_router
from ai_gateway.controller.analyst import make_analyst_router


def create_app() -> FastAPI:
    if not settings.anthropic_api_key:
        raise RuntimeError("ANTHROPIC_API_KEY is not configured. Check ai-gateway/.env.")

    ibor_repository = IborRepository(base_url=settings.structured_api_base)
    service = IborService(client=ibor_repository)
    anthropic_client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    market_tools = MarketTools()
    llm_service = LlmService(
        anthropic_client=anthropic_client,
        service=service,
        market_tools=market_tools,
        model=settings.anthropic_model,
    )

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        yield
        await ibor_repository.aclose()

    app = FastAPI(title="IBOR AI Gateway", version="0.2.0", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:4200", "http://localhost:5173"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health_router, tags=["health"])
    app.include_router(make_analyst_router(service, llm_service))

    @app.get("/", include_in_schema=False)
    def root():
        return {
            "service": "ibor-ai-gateway",
            "version": "0.2.0",
            "links": {"health": "/health", "docs": "/docs", "chat": "/analyst/chat"},
        }

    return app


app = create_app()
