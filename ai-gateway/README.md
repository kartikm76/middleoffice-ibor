# AI Gateway

FastAPI service that wraps the Spring Boot IBOR service with an AI analyst interface. All numbers come from Spring Boot — the LLM only reasons over them.

## Quick Start

```bash
# Prerequisites: Python 3.13+, uv (https://docs.astral.sh/uv/)

# Copy and set your OpenAI key
cp .env.example .env   # then set OPENAI_API_KEY

# Run
uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port 8000 --reload
```

Swagger UI: http://localhost:8000/docs

## Endpoints

All POST endpoints return an `IborAnswer` with `data`, `summary`, `citations`, and `gaps`.

| Endpoint | What it does |
|---|---|
| `POST /analyst/positions` | Portfolio positions as of a date |
| `POST /analyst/trades` | Trade history for a portfolio + instrument |
| `POST /analyst/prices` | Price series for an instrument |
| `POST /analyst/pnl` | P&L proxy: market value delta between two dates |
| `POST /analyst/chat` | Natural language question — LLM picks the right tool |
| `GET /health` | Health check |

## Example Requests

```bash
# Positions
curl -X POST http://localhost:8000/analyst/positions \
  -H "Content-Type: application/json" \
  -d '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03"}'

# Trades
curl -X POST http://localhost:8000/analyst/trades \
  -H "Content-Type: application/json" \
  -d '{"portfolio_code":"P-ALPHA","instrument_code":"EQ-AAPL","as_of":"2025-01-03"}'

# Prices
curl -X POST http://localhost:8000/analyst/prices \
  -H "Content-Type: application/json" \
  -d '{"instrument_code":"EQ-AAPL","from_date":"2025-01-01","to_date":"2025-01-10"}'

# PnL
curl -X POST http://localhost:8000/analyst/pnl \
  -H "Content-Type: application/json" \
  -d '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04","prior":"2025-01-03"}'

# Chat
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question":"What are the positions in P-ALPHA as of 2025-01-03?"}'
```

## Architecture

```
HTTP request
     ↓
controller/analyst.py       — routes (positions, trades, prices, pnl, chat)
     ↓                ↓
service/ibor_service.py     service/llm_agent.py
(data aggregation,          (OpenAI tool-calling loop,
 returns IborAnswer)         delegates to IborService)
     ↓
client/ibor_client.py       — async HTTP calls to Spring Boot
     ↓
Spring Boot :8080
```

## Package Structure

```
src/ai_gateway/
├── main.py                  # FastAPI app entry point
├── config/
│   ├── settings.py          # Loads config.yaml + .env
│   └── db.py                # PostgreSQL connection pool
├── client/
│   └── ibor_client.py       # HTTP client to Spring Boot
├── service/
│   ├── ibor_service.py      # Aggregates data, returns IborAnswer
│   └── llm_agent.py         # OpenAI tool-calling loop
├── controller/
│   ├── analyst.py           # All REST + chat endpoints
│   └── health.py            # /health
├── model/
│   ├── schemas.py           # IborAnswer, request models
│   └── rag_models.py        # RagDocument, RagChunk
└── rag/
    ├── agent.py             # Embedding + pgvector semantic search
    ├── local_store.py       # Postgres CRUD for RAG documents
    └── sql.py               # RAG SQL statements
```

## Configuration

`config.yaml` — non-secret settings:
```yaml
ibor:
  api_base: http://localhost:8080/api
openai:
  model: gpt-4o-mini
  embedding_model: text-embedding-3-small
database:
  dsn: postgresql://ibor:ibor@localhost:5432/ibor
```

`.env` — secrets (never committed):
```
OPENAI_API_KEY=sk-...
```

## Run Tests

```bash
uv run pytest -v
```
