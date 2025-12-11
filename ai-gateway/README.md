# AI Gateway (IBOR)
FastAPI service that exposes AI-assisted analyst endpoints backed by structured data and optional RAG capabilities.

Quick start
-----------
Prerequisites:
    - Python 3.13+
    - uv (https://docs.astral.sh/uv/)

Activate the virtual environment:
# from the project root
source .venv/bin/activate

Check installed packages:
```bash
# from the project root
pip list
```
Run the app (dev):

```bash
# from the project root
uv run uvicorn ai_gateway.app:app --host 127.0.0.1 --port 8000 --reload
```
 # Run tests
 PYTHONPATH=src .venv/bin/python -m pytest -vv
 OR
 .venv/bin/python -m pytest -q
 .venv/bin/python -m pytest -vv
```

Endpoints:
- GET / → {"service":"ibor-ai-gateway","status":"ok", ...}
- GET /health → {"status": "ok"}
- GET /hybrid → {"message": "This is the hybrid router"}

Troubleshooting:
- If you see `ModuleNotFoundError: No module named 'fastAPI'`, ensure imports use `from fastapi import ...` (all lowercase). This repo uses the correct casing.

## High-level architecture

FastAPI app (app.py)
        │
        ▼
AnalystOrchestrator (agents/orchestrator.py)
        ├─ StructuredTools (tools/structured.py)
        │       │
        │       ▼
        │   IborClient (clients/ibor_client.py)
        │       │
        │       ▼
        │   Structured API
        │
        └─ AnalystAgent (agents/analyst.py)
                │
                ▼
        AnalystAnswer dataclasses

 ## Flow

                ┌─────────────────────────┐
                │       FastAPI app       │
                │       (app.py)          │
                └────────────┬────────────┘
                             │ creates
                             ▼
             ┌───────────────────────────────┐
             │  AnalystOrchestrator          │
             │  (agents/orchestrator.py)     │
             │    • positions()              │
             │    • trades()                 │
             │    • prices()                 │
             │    • pnl()                    │
             └───────────────┬───────────────┘
                             │ injects
                  ┌──────────┴────────────┐
                  │                        │
                  ▼                        ▼
       ┌───────────────────────┐   ┌────────────────────────┐
       │     StructuredTools   │   │       AnalystAgent      │
       │ (tools/structured.py) │   │ (agents/analyst.py)     │
       │  wrappers over        │   │  builds AnalystAnswer   │
       │  IborClient           │   │  narratives & payloads  │
       └───────────┬───────────┘   └─────────────┬──────────┘
                   │ uses                      uses
                   ▼                             ▼
          ┌──────────────────┐          ┌────────────────┐
          │    IborClient    │          │   DataAgent    │
          │ (clients/        │          │ (agents/       │
          │  ibor_client.py) │          │  data_agent.py)│
          │  HTTP access     │          │  numeric view  │
          │  to structured   │          └────────────────┘
          │  services        │
          └──────────┬───────┘
                     │
                     ▼
            Structured API (Spring service)

Other pieces:
- Tracing utilities (infra/tracing.py) decorate agents/tools.
- AnalystService protocol (agents/orchestrator_interface.py) defines the router contract.
- make_analyst_router (routes/analyst_router.py) builds HTTP endpoints using any `AnalystService`.
- Health checks and additional routers (health.py, routes/hybrid_router.py).

Supporting modules:
- `agents/data_agent.py` – numeric-only operations over structured tools.
- `agents/rag_agent.py` – document ingestion + semantic search via pgvector and OpenAI embeddings.
- `infra/tracing.py` – OpenTelemetry setup and the `@traced` decorator.
- `routes/analyst_router.py` – router factory that accepts any `AnalystService`.
- `routes/hybrid_router.py` – additional hybrid/LLM endpoints.
- `health.py` – readiness/liveness endpoints.
- `config.py` – Pydantic settings (structured API base URL, OpenAI models, Postgres DSN, etc.).

## Key layers

1. **Clients**
   `IborClient` wraps HTTP calls to the structured Spring service and normalizes parameters.

2. **Tools**
   `StructuredTools` provides higher-level wrappers for positions, prices, drill-downs, etc.
   `DataAgent` offers numeric-only views with tracing instrumentation.

3. **Agents**
   `AnalystAgent` transforms structured data into analyst-friendly narratives (`AnalystAnswer`).
   `RagAgent` implements Retrieval-Augmented Generation for additional document-based context.
   `AnalystOrchestrator` composes clients, tools, and agents and exposes the `AnalystService` interface.

4. **Routes**
   `make_analyst_router` builds FastAPI endpoints (`/agents/analyst/...`) that depend on the `AnalystService` protocol.
   Additional routers (e.g., `hybrid_router`) provide other domain-specific endpoints.

## Dependency flow

1. `create_app()` (in `app.py`) builds an `IborClient`, `StructuredTools`, and `AnalystOrchestrator`.
2. `make_analyst_router(analyst_service)` returns a router wired to these services.
3. Each HTTP endpoint calls into the orchestrator, which uses structured tools/agents and returns `AnalystAnswerModel` responses.
4. Tracing instrumentation captures spans around key operations via `@traced`.

## Notable design choices

- **Protocol-based abstraction**: `AnalystService` allows the router to accept any conforming implementation, enabling easy testing and future orchestration variants.
- **Constructor injection**: `AnalystOrchestrator`, `StructuredTools`, and `IborClient` accept dependencies/configuration during construction, keeping state explicit.
- **Tracing**: OpenTelemetry spans instrument agents and tools for observability.
- **RAG support**: `RagAgent` encapsulates ingestion/search logic for document repositories (Postgres + pgvector).

## Future enhancements

- Add type checking to CI (`mypy`, `ruff`).
- Flesh out unit tests using fake implementations of `AnalystService`.
- Wrap tracing behind a simple interface if you want to further isolate domain code from OpenTelemetry specifics.

## Quick Checks
# positions
curl -s -X POST 'http://localhost:8000/agents/analyst/positions' \
  -H 'Content-Type: application/json' \
  -d '{"as_of":"2025-01-03","portfolio_code":"P-ALPHA"}' | jq

# trades
curl -s -X POST 'http://localhost:8000/agents/analyst/trades' \
  -H 'Content-Type: application/json' \
  -d '{"as_of":"2025-01-03","portfolio_code":"P-ALPHA","instrument_code":"EQ-IBM"}' | jq

# prices
curl -s -X POST 'http://localhost:8000/agents/analyst/prices' \
  -H 'Content-Type: application/json' \
  -d '{"instrument_code":"EQ-IBM","from_date":"2025-01-01","to_date":"2025-01-03"}' | jq

# pnl
curl -s -X POST 'http://localhost:8000/agents/analyst/pnl' \
  -H 'Content-Type: application/json' \
  -d '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03","prior":"2025-01-01"}' | jq


🧩 Two Parallel Worlds
WORLD 1 — Deterministic Analytics (No LLM)
Service Layer
    analyst.py
        •	deterministic business logic
        •	calls StructuredTools → SpringBoot
        •	returns AnalystAnswer dataclass
Controller Layer
    analyst_router.py
        •	converts HTTP JSON → Pydantic
        •	calls AnalystAgent
        •	converts AnalystAnswer → JSON
        •	exposes /agents/analyst/... endpoints
⸻
WORLD 2 — LLM / OpenAI Agent (AI Workflow)
Agent Layer (LLM brain)
    analyst_chat_agent.py
        •	defines OpenAI Agent
        •	registers tools: positions / trades / pnl
        •	sets system prompt
        •	runs Agent Handoff
        •	produces LLM-generated answers with structure
        •	interacts with OpenAI SDK
Controller Layer (HTTP wrapper)
    analyst_chat_router.py
        •	exposes one REST endpoint:
    POST /agents/analyst/chat
        •	receives user input { question, context... }
        •	calls analyst_chat_agent.ask(question)
        •	returns structured AI answer
        •	ensures JSON contract

| File                            | Layer       | LLM? | What it does                                                                       |
| ------------------------------- | ----------- | ---- | ---------------------------------------------------------------------------------- |
| `agents/analyst.py`             | Domain core | ❌    | Deterministic analytics using StructuredTools, returns `AnalystAnswer`.            |
| `routes/analyst_router.py`      | HTTP core   | ❌    | REST endpoints for positions/trades/pnl **without** OpenAI.                        |
| `openai/analyst_chat_agent.py`  | LLM wrapper | ✅    | OpenAI Agent with tools that call `AnalystAgent` under the hood.                   |
| `routes/analyst_chat_router.py` | HTTP LLM    | ✅    | `POST /agents/analyst/chat` → sends NL question into OpenAI Agent, returns answer. |
