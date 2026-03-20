# IBOR Platform

Investment Book of Record — positions, prices, trades, and P&L served through deterministic REST APIs and an AI analyst interface.

## Architecture

```
PostgreSQL 16 + pgvector
       ↓
ibor-server  (Spring Boot, Java 21)   — deterministic REST at :8080
       ↓
ai-gateway   (FastAPI, Python 3.13)   — AI analyst interface at :8000
```

---

## 1. PostgreSQL Setup

**Prerequisites:** Docker + Colima (or Docker Desktop)

```bash
# Start the database
docker compose up -d

# Load schema and seed data
./load_all.sh full
```

The database (`ibor`) is created with user `ibor` / password `ibor` on port `5432`.

Schema layers:
- `ibor.*` — curated facts and dimensions (positions, prices, trades, instruments)
- `stg.*` — staging tables for CSV ingest
- `ibor.rag_documents`, `ibor.rag_chunks` — pgvector store for RAG

---

## 2. Spring Boot Service

**Prerequisites:** Java 21, Maven

```bash
cd ibor-server
mvn spring-boot:run
```

Starts on `http://localhost:8080`. Swagger UI: `http://localhost:8080/swagger-ui.html`

**Key endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03` | All positions for a portfolio |
| GET | `/api/positions/{portfolio}/{instrument}?asOf=...` | Position drilldown with trade history |
| GET | `/api/prices/{instrumentCode}?from=...&to=...` | Price time series |
| GET | `/actuator/health` | Health check |

---

## 3. AI Gateway

**Prerequisites:** Python 3.13, [uv](https://docs.astral.sh/uv/)

```bash
cd ai-gateway

# Copy and fill in secrets
cp .env.example .env
# Set OPENAI_API_KEY in .env

# Start
uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port 8000 --reload
```

Starts on `http://localhost:8000`. Swagger UI: `http://localhost:8000/docs`

**Key endpoints** (all POST, return `IborAnswer` envelope):

| Path | Description |
|------|-------------|
| `POST /analyst/positions` | Positions with market value aggregate |
| `POST /analyst/trades` | Trade history for a portfolio + instrument |
| `POST /analyst/prices` | Price series with min/max/last summary |
| `POST /analyst/pnl` | P&L proxy: MV delta between two dates |
| `POST /analyst/chat` | Natural language — AI picks the right tool and returns grounded data |
| `GET /health` | Health check |

**Example — positions:**
```bash
curl -X POST http://localhost:8000/analyst/positions \
  -H "Content-Type: application/json" \
  -d '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03"}'
```

**Example — chat:**
```bash
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question":"What are the positions in P-ALPHA as of 2025-01-03?"}'
```

Every response is an `IborAnswer` with `data`, `summary`, `citations`, and `gaps` fields. The chat endpoint uses the same `IborAnswer` contract as all other endpoints — numbers always come from Spring Boot, never invented by the LLM.

---

## Project Structure

```
middleoffice-ibor/
├── docker-compose.yml
├── docker/                    # Postgres + pgvector Dockerfile
├── db/                        # SQL schema scripts (01–07) and seed CSVs
├── load_all.sh                # Full ETL bootstrap
├── ibor-server/               # Spring Boot service
│   └── src/main/java/com/kmakker/ibor/
└── ai-gateway/
    ├── config.yaml            # Non-secret settings (model, API base, DSN)
    ├── .env                   # Secrets (OPENAI_API_KEY) — never committed
    └── src/ai_gateway/
        ├── main.py            # FastAPI app entry point
        ├── config/
        │   ├── settings.py    # Loads config.yaml + .env
        │   └── db.py          # PostgreSQL connection pool (PgPool)
        ├── client/
        │   └── ibor_client.py # HTTP client to Spring Boot (async httpx)
        ├── service/
        │   ├── ibor_service.py  # Aggregates data, returns IborAnswer
        │   └── llm_agent.py     # OpenAI tool-calling loop
        ├── controller/
        │   ├── analyst.py     # REST + chat endpoints
        │   └── health.py      # /health
        ├── model/
        │   ├── schemas.py     # IborAnswer, request models
        │   └── rag_models.py  # RagDocument, RagChunk
        └── rag/
            ├── agent.py       # Embedding + pgvector search
            ├── local_store.py # Postgres CRUD for RAG documents
            └── sql.py         # RAG SQL statements
```

---

## Configuration

`ai-gateway/config.yaml` — non-secret settings:
```yaml
ibor:
  api_base: http://localhost:8080/api
openai:
  model: gpt-4o-mini
  embedding_model: text-embedding-3-small
database:
  dsn: postgresql://ibor:ibor@localhost:5432/ibor
```

`ai-gateway/.env` — secrets (not committed):
```
OPENAI_API_KEY=sk-...
# Optional overrides:
# PG_DSN=postgresql://...
# STRUCTURED_API_BASE=http://...
```
