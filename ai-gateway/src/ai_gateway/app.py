from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI

from ai_gateway.config import settings
from ai_gateway.clients.ibor_client import IborClient
from ai_gateway.tools.structured import StructuredTools

from ai_gateway.agents.analyst import AnalystAgent
from ai_gateway.agents.orchestrator import AnalystOrchestrator

from ai_gateway.health import router as health_router
from ai_gateway.routes.hybrid_router import router as hybrid_router
from ai_gateway.routes.analyst_router import make_analyst_router

from ai_gateway.routes.analyst_llm_router import make_analyst_llm_router
from ai_gateway.openai.analyst_llm_agent import AnalystLLMAgent
from ai_gateway.openai.tool_runners import (
	PositionsRunner,
	TradesRunner,
	PnLRunner,
	PricesRunner,
)

def create_app() -> FastAPI:
	app = FastAPI(title="IBOR AI Gateway", version="0.1.0")

	app.add_middleware(
		CORSMiddleware,
		allow_origins=["http://localhost:4200"],  # Angular dev
		allow_credentials=True,
		allow_methods=["*"],
		allow_headers=["*"],
	)

	# --- Core structured dependencies (Spring client) ---
	ibor_client = IborClient(base_url=settings.structured_api_base)
	tools = StructuredTools(ibor_client=ibor_client)

	# Deterministic analyst service used by /api/analyst/* REST endpoints
	analyst_service = AnalystOrchestrator(client=ibor_client, tools=tools)

	# --- Pure Python AnalystAgent used for both REST + LLM tools ---
	analyst_agent = AnalystAgent(structured_tools=tools)

	# Tool runners (wrap AnalystAgent methods for positions / trades / pnl / prices)
	positions_runner = PositionsRunner(analyst_agent=analyst_agent)
	trades_runner = TradesRunner(analyst_agent=analyst_agent)
	pnl_runner = PnLRunner(analyst_agent=analyst_agent)
	prices_runner = PricesRunner(analyst_agent=analyst_agent)

	# OpenAI client (prefer settings-derived API key from .env)
	if not settings.openai_api_key:
		raise RuntimeError(
			"OPENAI_API_KEY is not configured. Check ai-gateway/.env or environment settings."
		)
	openai_client = OpenAI(api_key=settings.openai_api_key)

	# LLM agent that uses OpenAI + tool runners
	llm_agent = AnalystLLMAgent(
		client=openai_client,
		positions_runner=positions_runner,
		trades_runner=trades_runner,
		pnl_runner=pnl_runner,
		prices_runner=prices_runner,
	)

	# --- Routers ---
	app.include_router(health_router, tags=["health"]) # Health
	app.include_router(hybrid_router, tags=["hybrid"]) # Hybrid (deterministic hybrid REST)
	app.include_router(make_analyst_router(analyst_service), prefix="", tags=["analyst"]) # Deterministic Analyst REST (positions / trades / pnl proxies)
	app.include_router(make_analyst_llm_router(llm_agent), prefix="", tags=["analyst-llm"]) # LLM-based Analyst chat (OpenAI Agent + tools)

	# Root
	@app.get("/", include_in_schema=False)
	def root():
		return {
			"service": "ibor-ai-gateway",
			"status": "ok",
			"links": {
				"health": "/health",
				"docs": "/docs",
				"openapi": "/openapi.json",
				"analyst_chat": "/agents/analyst/chat",
			},
		}

	return app

app = create_app()