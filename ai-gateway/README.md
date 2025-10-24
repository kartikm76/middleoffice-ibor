IBOR AI Gateway
================

FastAPI service exposing health and hybrid routes.

Quick start
-----------

Prerequisites:

- Python 3.13+
- uv (https://docs.astral.sh/uv/)

Run the app (dev):

```bash
# from the project root
uv run uvicorn ai_gateway.app:app --host 127.0.0.1 --port 8000 --reload
```

Endpoints:

- GET / → {"service":"ibor-ai-gateway","status":"ok", ...}
- GET /health → {"status": "ok"}
- GET /hybrid → {"message": "This is the hybrid router"}

Troubleshooting:

- If you see `ModuleNotFoundError: No module named 'fastAPI'`, ensure imports use `from fastapi import ...` (all lowercase). This repo uses the correct casing.
