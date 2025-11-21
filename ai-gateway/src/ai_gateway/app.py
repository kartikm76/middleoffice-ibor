from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ai_gateway.clients.ibor_client import IborClient
from ai_gateway.config import settings
from ai_gateway.health import router as health_router
from ai_gateway.routes.hybrid_router import router as hybrid_router
from ai_gateway.routes.analyst_router import make_analyst_router
from ai_gateway.agents.orchestrator import AnalystOrchestrator
from ai_gateway.tools.structured import StructuredTools


def create_app() -> FastAPI:
	app = FastAPI(title="IBOR AI Gateway", version="0.1.0")
	app.add_middleware(
		CORSMiddleware,
		allow_origins=["http://localhost:4200"],  # Angular dev
		allow_credentials=True,
		allow_methods=["*"],
		allow_headers=["*"],
	)

	# Build dependencies explicitly
	ibor_client = IborClient(base_url = settings.structured_api_base)
	tools = StructuredTools(ibor_client = ibor_client)
	analyst_service = AnalystOrchestrator(client = ibor_client, tools = tools)

	# mount routers
	# Health
	app.include_router(health_router, tags=["health"])
	# Hybrid
	app.include_router(hybrid_router, tags=["hybrid"])
	# Analyst
	app.include_router(make_analyst_router(analyst_service), prefix="", tags=["analyst"])

	# root
	@app.get("/", include_in_schema=False)
	def root():
		return {
			"service": "ibor-ai-gateway",
			"status": "ok",
			"links": {
				"health": "/health", "docs": "/docs", "openapi": "/openapi.json",
			},
		}
	return app

app = create_app()