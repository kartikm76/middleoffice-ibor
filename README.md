# IBOR Platform — AI-Powered Investment Book of Record


## What This Platform Does

An Investment Book of Record (IBOR) is the authoritative, real-time view of a portfolio's holdings — positions, trades, prices, and P&L — used by portfolio managers to make investment decisions.

This platform goes one step further: it pairs deterministic financial data with an AI analyst so you can ask questions in plain English and get grounded, data-backed answers.

---

## Asking Questions with AI

The `/analyst/chat` endpoint is the centrepiece. You send a question, and the platform:

1. **Understands your intent** — OpenAI reads the question and selects the right data tool (positions, trades, prices, or P&L)
2. **Fetches real numbers** — the Spring Boot service queries PostgreSQL and returns exact figures
3. **Writes a natural answer** — OpenAI narrates the data into plain English, using only the numbers retrieved (never invented)

```
You ask:  "What are the positions in P-ALPHA as of Feb 4, 2025?"

Platform: → identifies tool: positions(P-ALPHA, 2025-02-04)
          → fetches from DB: EQ-IBM short 10 @ $175.25, FUT-ESZ5 long 1 @ $5,205.25
          → AI writes:

"As of February 4, 2025, portfolio P-ALPHA holds two positions.
 It has a short position of 10 IBM shares (EQ-IBM) valued at -$1,752.50,
 and a long position in one ES December futures contract (FUT-ESZ5)
 valued at $260,262.50. Total portfolio market value is $258,510.00."
```

The AI never invents numbers — it only narrates data that came from the database.

---

## What You Can Ask

| Question type | Example |
|---|---|
| Positions | "What are the holdings in P-ALPHA as of January 3, 2025?" |
| Trades | "Show me the trade history for IBM in P-ALPHA as of Feb 4" |
| Prices | "What was the price of EQ-AAPL between Jan 1 and Feb 4, 2025?" |
| P&L | "What is the P&L of P-ALPHA between Jan 3 and Feb 4, 2025?" |

---

## Try It Now

Start the platform (see [Quick Start](#quick-start) below), then open the Swagger UI:

```
http://localhost:8000/docs
```

Or use `curl`:

```bash
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the positions in P-ALPHA as of 2025-02-04?"}'
```

Every response follows the same structure:

```json
{
  "question": "What are the positions in P-ALPHA as of 2025-02-04?",
  "as_of": "2025-02-04",
  "summary": "As of February 4, 2025, portfolio P-ALPHA holds two positions...",
  "data": { "positions": [...], "totalMarketValue": 258510.0, "count": 2 },
  "source": "http://localhost:8080/api/positions?portfolioCode=P-ALPHA&asOf=2025-02-04",
  "gaps": []
}
```

- `summary` — the AI's plain-English narrative
- `data` — the raw numbers, always present so you can verify
- `source` — the exact Spring Boot URL that was called
- `gaps` — any missing parameters or errors the AI flagged

---

---

## Technical Details

### Architecture

Three tiers. Numbers flow up from PostgreSQL; questions flow down from the user.

```
┌─────────────────────────────────────────────────────────────┐
│  User / Swagger UI                                          │
│  POST /analyst/chat  {"question": "..."}                    │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│  ai-gateway  (FastAPI · Python 3.13 · :8000)                │
│                                                             │
│  controller/analyst.py                                      │
│       │                    │                                │
│       ▼                    ▼                                │
│  service/ibor_service  service/llm_service                  │
│  (raw data only)       (OpenAI orchestration)               │
│       │                    │                                │
│       │          Step 1: tool selection → which endpoint?   │
│       │          Step 2: narration → write plain English    │
│       │                    │                                │
│  repository/ibor_repository.py  (async httpx)               │
└────────────────────────────┬────────────────────────────────┘
                             │  HTTP
┌────────────────────────────▼────────────────────────────────┐
│  ibor-server  (Spring Boot 3.5 · Java 21 · :8080)           │
│                                                             │
│  PositionController → PositionService → jOOQ Repository     │
│  PriceController   → PriceService    → jOOQ Repository      │
│  TransactionLineageController → ...                         │
└────────────────────────────┬────────────────────────────────┘
                             │  SQL
┌────────────────────────────▼────────────────────────────────┐
│  PostgreSQL 16 + pgvector  (:5432)                          │
│                                                             │
│  ibor.*  — curated facts & dimensions (SCD2)               │
│  stg.*   — staging tables for CSV ingest                   │
│  rag_*   — pgvector embeddings for semantic search          │
└─────────────────────────────────────────────────────────────┘
```

### Two-Step LLM Flow (Chat Endpoint)

```
User question
     │
     ▼
[Step 1 — Tool Selection]
OpenAI receives the question + tool definitions
Responds with: call positions(portfolioCode=P-ALPHA, asOf=2025-02-04)
     │
     ▼
IborService.positions()  →  IborRepository  →  Spring Boot  →  PostgreSQL
Returns IborAnswer with exact market values, quantities, prices
     │
     ▼
[Step 2 — Narration]
OpenAI receives: {question, as_of, data: {...}}
Responds with: natural language summary (uses only the numbers in data)
     │
     ▼
IborAnswer returned to user (summary + data + source URL)
```

### REST Endpoints (ai-gateway :8000)

| Method | Path | Input | Description |
|--------|------|-------|-------------|
| POST | `/analyst/positions` | `portfolio_code`, `as_of` | Positions with total market value |
| POST | `/analyst/trades` | `portfolio_code`, `instrument_code`, `as_of` | Trade history |
| POST | `/analyst/prices` | `instrument_code`, `from_date`, `to_date` | Price series with min/max/last |
| POST | `/analyst/pnl` | `portfolio_code`, `as_of`, `prior` | P&L: MV delta between two dates |
| POST | `/analyst/chat` | `question` (free text) | AI analyst — natural language |
| GET | `/health` | — | Health check |

### REST Endpoints (ibor-server :8080)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/positions` | Portfolio positions as-of a date |
| GET | `/api/positions/{portfolio}/{instrument}` | Position drilldown with trade history |
| GET | `/api/prices/{instrumentCode}` | Price time series |
| GET | `/api/analytics/*` | Brinson attribution, returns |
| GET | `/actuator/health` | Health check |

Swagger UI: `http://localhost:8080/swagger-ui.html`

### Project Structure

```
middleoffice-ibor/
├── docker-compose.yml              # PostgreSQL 16 + pgvector
├── db/
│   ├── init/                       # SQL schema scripts (01–07)
│   └── data/                       # Seed CSV files
├── load_all.sh                     # Full ETL bootstrap (schema → staging → curated)
├── start.sh                        # One-command startup: Colima → DB → Java → Python
├── test.sh                         # Smoke test: curl all endpoints
│
├── ibor-server/                    # Spring Boot service
│   └── src/main/java/com/kmakker/ibor/
│       ├── controller/             # REST controllers
│       ├── service/                # Business logic
│       └── repository/             # jOOQ data access
│
└── ai-gateway/                     # FastAPI AI gateway
    ├── config.yaml                 # Non-secret settings
    ├── .env                        # OPENAI_API_KEY (never committed)
    ├── .env.example                # Template
    └── src/ai_gateway/
        ├── main.py                 # FastAPI app entry point
        ├── config/
        │   ├── settings.py         # Loads config.yaml + .env
        │   └── db.py               # PostgreSQL connection pool
        ├── repository/
        │   └── ibor_repository.py  # Async HTTP client to Spring Boot
        ├── service/
        │   ├── ibor_service.py     # Data aggregation, returns IborAnswer
        │   └── llm_service.py      # OpenAI two-step orchestration
        ├── controller/
        │   ├── analyst.py          # All endpoints (REST + chat)
        │   └── health.py           # /health
        ├── model/
        │   ├── schemas.py          # IborAnswer, all request models
        │   └── rag_models.py       # RagDocument, RagChunk
        └── rag/
            ├── rag_service.py      # Embedding + pgvector semantic search
            ├── local_store.py      # Postgres CRUD for RAG documents
            └── sql.py              # RAG SQL statements
```

### Database Schema

| Schema | Purpose |
|--------|---------|
| `ibor.*` | Curated facts and dimensions — positions, prices, trades, instruments (SCD2) |
| `stg.*` | Staging tables — raw CSV ingest before transformation |
| `ibor.rag_documents`, `ibor.rag_chunks` | pgvector store for RAG semantic search |

Key tables: `dim_instrument`, `dim_portfolio`, `fact_position_snapshot`, `fact_price`, `fact_trade`

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16, pgvector |
| Java service | Java 21, Spring Boot 3.5, jOOQ 3.18, Lombok |
| Python gateway | Python 3.13, FastAPI, Pydantic 2, httpx, OpenAI SDK |
| Package manager | uv (Python), Maven (Java) |
| Infrastructure | Docker, Colima |

---

## Quick Start

### Prerequisites

- [Colima](https://github.com/abiosoft/colima) or Docker Desktop
- Java 21+
- Python 3.13+, [uv](https://docs.astral.sh/uv/)
- An OpenAI API key

### 1. Configure secrets

```bash
cp ai-gateway/.env.example ai-gateway/.env
# Edit ai-gateway/.env and set OPENAI_API_KEY=sk-...
```

### 2. Start everything

```bash
./start.sh
```

This script starts Colima, PostgreSQL, loads the schema and seed data, starts the Spring Boot service, and starts the Python gateway — with health checks at each step.

### 3. Verify

```bash
./test.sh
```

Runs curl against every endpoint and prints pass/fail.

### Manual startup (alternative)

```bash
# Database
colima start
docker-compose up -d
./load_all.sh full

# Spring Boot
cd ibor-server
JAVA_HOME=$(/usr/libexec/java_home -v 23) mvn spring-boot:run

# Python gateway (new terminal)
cd ai-gateway
uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port 8000 --reload
```

### Seed Data

The platform ships with sample data for portfolio **P-ALPHA**:

| Instrument | Type | Dates available |
|-----------|------|----------------|
| EQ-IBM | Equity | 2025-01-03, 2025-02-04 |
| EQ-AAPL | Equity | 2025-01-03 |
| FUT-ESZ5 | Futures | 2025-02-04 |
| BOND-UST10 | Bond | 2025-01-03 |
| OPT-AAPL-20250117-150C | Option | 2025-01-03 |
