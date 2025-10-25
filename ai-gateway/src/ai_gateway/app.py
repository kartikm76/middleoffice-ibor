from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

from ai_gateway.infra.tracing import init_tracing
from ai_gateway.health import router as health_router
from ai_gateway.routes.hybrid_router import router as hybrid_router
from ai_gateway.routes.analyst_router import router as analyst_router

def create_app() -> FastAPI:
	app = FastAPI(title="IBOR AI Gateway", version="0.1.0")
	app.add_middleware(
		CORSMiddleware,
		allow_origins=["http://localhost:4200"],  # Angular dev
		allow_credentials=True,
		allow_methods=["*"],
		allow_headers=["*"],
	)
	# mount routers
	# Health
	app.include_router(health_router, tags=["health"])
	# Hybrid
	app.include_router(hybrid_router, tags=["hybrid"])
	# Analyst
	app.include_router(analyst_router, prefix="", tags=["analyst"])

	# root
	@app.get("/", include_in_schema=False)
	def root():
		return {
			"service": "ibor-ai-gateway",
			"status": "ok",
			"links": {
				"health": "/health",
				"docs": "/docs",
				"openapi": "/openapi.json",
			},
		}
	return app

app = create_app()