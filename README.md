# IBOR Hybrid Starter
(Postgres + pgvector + Spring Boot + Python AI Gateway)

## 1. Project Purpose

This repository provides a compact but realistic **Investment Book of Record (IBOR)** starter kit. It demonstrates how to:

- Load curated multi-asset-class data (instruments, trades, FX, prices, positions) into Postgres.
- Expose **deterministic, reliable IBOR APIs** through Spring Boot.
- Use a Python **AI Gateway** (FastAPI + OpenAI SDK) to expose an “AI Analyst” interface.
- Keep **all numeric truth in SQL**, while allowing AI to summarize, explain, and answer questions.
- Extend into RAG (pgvector) for document/notes retrieval when desired.

**Principle:**
> Numbers and facts come from SQL.
> Reasoning and narrative come from AI.

---

## 2. High-Level Architecture

```
                   ┌────────────────────────┐
                   │ UI / CLI / Tools       │
                   │ (curl, Angular, etc.)  │
                   └───────────┬────────────┘
                               │ HTTP
                               ▼
                 ┌──────────────────────────────┐
                 │ ai-gateway (FastAPI, Python) │
                 │ - OpenAI SDK Agent           │
                 │ - Structured Tools           │
                 └─────────────┬────────────────┘
                               │ HTTP
                               ▼
                 ┌──────────────────────────────┐
                 │ ibor-server (Spring Boot)    │
                 │ - Deterministic IBOR APIs    │
                 │ - JDBC over curated schema   │
                 └─────────────┬────────────────┘
                               │ JDBC
                               ▼
                 ┌──────────────────────────────┐
                 │ Postgres 16 + pgvector       │
                 │ - ibor.* curated schema      │
                 │ - stg.* staging tables       │
                 │ - rag_* vector store         │
                 └──────────────────────────────┘
```
---
## 3. Project Structure

    middleoffice-ibor/
    ├ docker/
    │  └ db/
    │     ├ data/                 # Sample CSV data
    │     └ init/                 # SQL schema, staging, loaders
    │        ├ 01_main_schema.sql
    │        ├ 02_staging_schema.sql
    │        ├ 03_audit_trigger.sql
    │        ├ 04_loaders.sql
    │        ├ 05_helpers.sql
    │        ├ 06_vw_instrument.sql
    │        └ run_all.sql
    ├ docker-compose.yml          # Postgres 16 + pgvector
    ├ load_all.sh                 # Bootstrap schemas + staging + curated
    │
    ├ ibor-server/                # Spring Boot IBOR structured APIs
    │  ├ controllers/             # positions, trades, prices, lineage
    │  ├ services/
    │  └ repositories/
    │
    ├ ai-gateway/                 # Python FastAPI + OpenAI SDK
    │  ├ agents/
    │  ├ routes/
    │  ├ openai/
    │  └ clients/
    │
    └ README.md
```
---

## 4. Get Started

4.1 Prerequisites
    Docker + docker-compose
    Java 21+
    Python 3.13+ (recommended via uv)
    Maven 3.9+
    OpenAI API key
    export OPENAI_API_KEY="sk-..."

4.2 Start Postgres (with pgvector)
    docker compose up -d
    Verify:
        docker-compose ps
        docker logs db | grep "database system is ready"

4.3 Initialize schemas, load staging, run loaders
    Option 1: Full setup
        ./load_all.sh full

    Option 2: Individual steps
        ./load_all.sh init_infra
        ./load_all.sh load_staging
        ./load_all.sh load_main

    It performs:
        init_infra → create all schemas, helpers, loaders
        load_staging → loads CSVs into stg.* tables
        load_main → runs curated loaders into ibor.*

4.4 Run the Spring Boot server
    cd ibor-server

    # Option A: auto-reload
    ./mvnw spring-boot:run

    # Option B: package & run jar
    ./mvnw -q clean package
    java -jar target/ibor-server-*.jar


4.5 Run the AI Gateway
    cd ai-gateway
    uv run uvicorn ai_gateway.app:app --host 127.0.0.1 --port 8000 --reload
---

## 5. Test the System
5.1 Spring Boot Structured APIs

Positions (as-of snapshot)
curl 'http://localhost:8080/api/positions?asOf=2025-01-03&portfolioCode=P-ALPHA&page=1&size=50' | jq

Position Composition
curl 'http://localhost:8080/api/positions/composition?asOf=2025-01-03&portfolioCode=P-ALPHA' | jq

Trades (as-of snapshot)
curl 'http://localhost:8080/api/trades?asOf=2025-01-03&portfolioCode=P-ALPHA&instrumentCode=EQ-IBM&page=1&size=50' | jq

Prices (as-of snapshot)
curl 'http://localhost:8080/api/prices?instrumentCode=EQ-IBM&fromDate=2025-01-01&toDate=2025-01-03' | jq

PnL (as-of snapshot)
curl 'http://localhost:8080/api/pnl?portfolioCode=P-ALPHA&asOf=2025-01-03&prior=2025-01-01' | jq

5.2 Python AI Gateway (Analyst API)
Analyst → Positions
curl -s -X POST 'http://localhost:8000/agents/analyst/positions' \
  -H 'Content-Type: application/json' \
  -d '{"as_of":"2025-01-03","portfolio_code":"P-ALPHA"}' | jq

Analyst → Trades
curl -s -X POST 'http://localhost:8000/agents/analyst/trades' \
  -H 'Content-Type: application/json' \
  -d '{"as_of":"2025-01-03","portfolio_code":"P-ALPHA","instrument_code":"EQ-IBM"}' | jq

Analyst → Prices
curl -s -X POST 'http://localhost:8000/agents/analyst/prices' \
  -H 'Content-Type: application/json' \
  -d '{"instrument_code":"EQ-IBM","from_date":"2025-01-01","to_date":"2025-01-03"}' | jq

Analyst → PnL
curl -s -X POST 'http://localhost:8000/agents/analyst/pnl' \
  -H 'Content-Type: application/json' \
  -d '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03","prior":"2025-01-01"}' | jq