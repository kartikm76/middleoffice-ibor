from fastapi import FastAPI
from ai_gateway.health import router as health_router
from ai_gateway.routes.hybrid_router import router as hybrid_router

app = FastAPI(title="IBOR AI Gateway", version="0.1.0")

# mount routers
app.include_router(health_router)
app.include_router(hybrid_router)

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