# IBOR Analyst — AI-Powered Investment Book of Record

An Investment Book of Record (IBOR) is the authoritative, real-time view of a portfolio's holdings — positions, trades, prices, and P&L — used by portfolio managers to make investment decisions.

This platform pairs deterministic financial data (from PostgreSQL) with an AI analyst (Claude Sonnet 4.6) so analysts can ask questions in plain English and get grounded, data-backed answers enriched with live market context from Yahoo Finance.

**Core philosophy:** numbers/facts come from SQL, reasoning/narrative come from AI.

---

## Retrieval-Augmented Generation (RAG): A Two-Phase Story

### Phase 1 (Current): Conversation Context & Memory
IBOR Analyst uses **RAG with pgvector embeddings** to maintain conversational context:
- **Conversation Memory** — Every question and answer is embedded and stored
- **Multi-turn Context** — Semantic search retrieves relevant past conversations
- **Contextual Awareness** — Follow-up questions understand prior context without re-stating it
- **Storage** — PostgreSQL with pgvector for semantic similarity search

This enables coherent, context-aware multi-turn conversations where the AI analyst maintains discussion history.

### Phase 2 (Coming): Document-Augmented Analysis
RAG expands to user-uploaded documents (regulatory filings, research, earnings reports) blended with IBOR data and market context.

**The Vision:** Start with conversation memory (Phase 1), evolve to document-rich analysis (Phase 2), create a unified intelligence layer over portfolio data.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          IBOR AI Platform                                    │
│                                                                               │
│  ┌──────────────┐    ┌──────────────────────┐    ┌────────────────────────┐ │
│  │  PostgreSQL  │    │   Spring Boot :8080   │    │  FastAPI AI Gateway   │ │
│  │  16+pgvector │◄───│  Deterministic REST   │◄───│       :8000           │ │
│  │              │    │  positions / prices   │    │  Octopus Orchestrator │ │
│  │  ibor.*      │    │  trades / analytics   │    │                        │ │
│  │  stg.*       │    └──────────────────────┘    └──────────┬─────────────┘ │
│  │  rag_*       │                                            │               │
│  └──────────────┘                                            │               │
│                                                    ┌─────────▼─────────────┐ │
│  ┌──────────────┐                                  │   Two-Stage Fan-Out   │ │
│  │  yfinance    │◄─────────────────────────────────│   (Octopus Pattern)   │ │
│  │  (Yahoo Fin) │    live market data              │                        │ │
│  └──────────────┘                                  │  LLM #1: Intent Parse │ │
│                                                    │  Stage 1: IBOR fetch  │ │
│  ┌──────────────┐                                  │  Stage 2: Market fetch│ │
│  │  Claude      │◄─────────────────────────────────│  LLM #2: Synthesis    │ │
│  │  Sonnet 4.6  │    narration / synthesis         └───────────────────────┘ │
│  └──────────────┘                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Stack

| Layer | Technology |
|-------|-----------|
| **Database** | PostgreSQL 16 + pgvector (embeddings-ready) |
| **REST API** | Spring Boot 3.5.5, Java 21, jOOQ 3.18.7, Maven |
| **AI Gateway** | FastAPI 0.119+, Python 3.13, Anthropic SDK, uv (frozen deps) |
| **LLM** | Claude Sonnet 4.6 (claude-sonnet-4-6) |
| **Market Data** | yfinance 0.2.50+ (Yahoo Finance) |
| **Frontend** | React 18, Vite, AG Grid, Ant Design |
| **Async** | asyncio.gather + asyncio.to_thread |
| **Deployment** | Docker Compose (local), Railway.app (production) |

---

## How It Works

### The Octopus Fan-Out Pattern

When a portfolio manager asks a question, the AI gateway runs a two-stage orchestration:

**Stage 1 — Intent Parse (LLM call #1)**

Claude reads the question and outputs a structured plan: which IBOR tools to call, any tickers explicitly named, and whether macro data is relevant.

**Stage 2a — Explicit tickers: True Octopus blast**

If the question names specific tickers (e.g. "compare NVDA and AMD"), all IBOR fetches and all market data fetches fire simultaneously via `asyncio.gather`:

```
Question: "Compare NVDA and AMD positions and latest news"
                    │
         ┌──────────▼──────────────────────────────────────────┐
         │              asyncio.gather (all at once)            │
         │  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
         │  │ IBOR:       │  │ Market:  │  │ Market:       │  │
         │  │ positions() │  │ NVDA     │  │ AMD           │  │
         │  │ prices()    │  │ snapshot │  │ snapshot      │  │
         │  │             │  │ news     │  │ news          │  │
         │  │             │  │ earnings │  │ earnings      │  │
         │  └─────────────┘  └──────────┘  └───────────────┘  │
         └──────────────────────────────────────────────────────┘
                    │
         ┌──────────▼──────────┐
         │  LLM #2: Synthesis  │
         │  (Claude Sonnet)    │
         └─────────────────────┘
```

**Stage 2b — Implicit tickers: Two-stage fan-out**

If the question is portfolio-level (e.g. "show positions"), IBOR data is fetched first, equity instrument codes (EQ-AAPL, EQ-NVDA...) are extracted and stripped to bare tickers, then market data is fetched in a second parallel blast:

```
Question: "What are the top equity positions?"
                    │
         ┌──────────▼──────────┐
         │  Stage 1: IBOR      │  (asyncio.gather all IBOR calls)
         │  positions(P-ALPHA) │
         └──────────┬──────────┘
                    │  extract EQ-* codes → [AAPL, NVDA, MSFT, AMD, JPM]
         ┌──────────▼──────────────────────────────────┐
         │  Stage 2: Market (asyncio.gather, up to 10) │
         │  snapshot + news + earnings per ticker       │
         │  + macro (VIX, S&P 500, 10Y yield)          │
         └──────────┬──────────────────────────────────┘
                    │
         ┌──────────▼──────────┐
         │  LLM #2: Synthesis  │
         └─────────────────────┘
```

### Synthesis

Claude Sonnet 4.6 combines IBOR facts + market context into analyst-grade prose:
- IBOR numbers are ground truth — never rounded, estimated, or invented
- Market data adds intelligence (price momentum, news catalysts, earnings risk)
- Response is 4–8 sentences of flowing prose, no bullet points
- Surfaces one key risk or opportunity the PM should act on

### External Market Data (Yahoo Finance)

Four async tools fetch live data:

| Tool | What it returns |
|------|----------------|
| `get_market_snapshot(ticker)` | Price, change%, volume, market cap, P/E, 52-week range, analyst target & rating |
| `get_news(ticker)` | Latest 5 headlines with source and timestamp |
| `get_earnings(ticker)` | Next earnings date, forward EPS estimate, trailing EPS |
| `get_macro_snapshot()` | S&P 500 level, VIX, US 10-year Treasury yield |

---

## Quick Start

### Running the Application

```bash
# 1. Start services (all 4: PostgreSQL, Spring Boot, FastAPI, React)
./start_all.sh

# 2. Open UI
http://localhost:5173

# 3. Or test API endpoints
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question":"What are the top positions?"}'
```

### Testing

```bash
# Health checks
curl http://localhost:8000/health
curl http://localhost:8080/health

# Sample chat query
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question":"Analyze the Technology strategy"}'

# Swagger UI
http://localhost:8080/swagger-ui.html  (Spring Boot)
http://localhost:8000/docs             (FastAPI)
```

---

## Database Schema

Three schemas in PostgreSQL:

### `ibor.*` — Curated Facts & Dimensions (Ground Truth)

**STAR Schema ER Diagram:**

```
                              dim_portfolio
                                    │
                     ┌──────────────┼──────────────┐
                     │              │              │
               dim_account    dim_strategy    dim_currency
                     │              │              │
                     └──────────────┼──────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
    fact_position_snapshot   fact_price_fxrate       fact_trade
           │                        │                        │
           └────────────────────────┼────────────────────────┘
                                    │
                              dim_instrument
```

**Dimension Tables (SCD2 with history tracking):**
- `dim_instrument` — Master instruments (equities, bonds, futures, options, FX, indices)
- `dim_portfolio` — Portfolio masters and attributes
- `dim_account` — Trading accounts and characteristics
- `dim_account_portfolio` — Many-to-many join between accounts and portfolios
- `dim_currency` — Currency codes and properties
- `dim_strategy` — Investment strategy definitions

**Fact Tables (immutable, append-only):**
- `fact_position_snapshot` — Holdings at portfolio level, as-of dates
- `fact_price` — Historical prices across time
- `fact_fx_rate` — Foreign exchange rates across time
- `fact_trade` — Transaction history with full lineage at account level
- `fact_cash_event` — Dividends, interest, cash transfers

### `stg.*` — Staging Tables (ETL Landing Zone)

Temporary landing zone for CSV data before validation and promotion to ibor.*. Cleared after each ETL run. See `ibor-db/init/03-staging.sql` for field mappings.

### `rag_*` — pgvector Embeddings (Phase 2)

Reserved for semantic search and document RAG:
- `rag_document` — Embedded research documents
- `rag_position_notes` — Embedded analyst notes
- `rag_index` — Embedding vectors (stored in pgvector)

---

## ETL Pipeline

The ETL pipeline loads 23 CSV files into PostgreSQL, validates data integrity, and promotes clean data to the curated `ibor.*` schema.

### Input

CSV files in `ibor-db/data/`:
- Instruments (201 total)
- Portfolios & accounts
- Positions (as-of multiple dates)
- Prices (8 date snapshots)
- FX rates (8 date snapshots)
- Trades & cash events

### Process

```
CSV files → stg.* (staging) → ibor.* (curated) → fact_* & dim_* tables
```

1. **Schema Creation** — SQL scripts 01-06 in `ibor-db/init/`
2. **Data Load** — CSVs → `stg.*` tables
3. **Transformation** — Validation, deduplication, SCD2 dimension tracking
4. **Promotion** — `stg.*` → `ibor.*` (fact tables and dimension tables)
5. **Cleanup** — `stg.*` tables cleared

### Run ETL

```bash
# Full reload
./ibor-starter/2_data_bootstrap.sh full

# Individual phases
./ibor-starter/2_data_bootstrap.sh init_infra     # Create schema only
./ibor-starter/2_data_bootstrap.sh load_staging   # CSV → stg.*
./ibor-starter/2_data_bootstrap.sh load_main      # stg.* → ibor.*
```

**Details:** See `ibor-db/init/` for SQL scripts and `ibor-starter/README.md` for CSV field mappings.

### Data Quality

- **Comprehensive instruments** across 8 asset classes
- **Price history** with real Yahoo Finance historical data
- **FX rates** for major currency pairs
- **Bond prices** computed from real treasury yields using standard bond pricing
- **Trades** with full account-level lineage and cash event tracking

---

## Market Data in the Database

The database contains real historical market data downloaded from Yahoo Finance:

- **US Equities:** AAPL, MSFT, NVDA, GOOGL, META, AMZN, TSLA, JPM, BAC, GS, JNJ, UNH, XOM, CVX, BA, SPY, QQQ, GLD, TLT, and 80+ more
- **European Equities:** SAP, ASML, LVMH, Nestlé, Shell, AstraZeneca, and more (GBP/CHF where applicable)
- **Bonds:** US Treasury notes + corporate bonds with computed pricing
- **Futures & Options:** Rates, indices, equity derivatives
- **FX Pairs:** 7 direct + 3 inverse (EUR/USD, GBP/USD, JPY/USD, etc.)
- **Indices:** S&P 500, Nasdaq-100, European indices

**Date Range:** 2025-01-02 to 2026-03-20 (8 snapshots)

---

## API Curl Commands

<details>
<summary><strong>Click to expand API examples</strong></summary>

### Chat Endpoint (AI Analyst)

```bash
# Simple question
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the top 3 positions in P-ALPHA?",
    "portfolio_code": "P-ALPHA",
    "market_contents": true
  }'

# With specific tickers (triggers Octopus blast)
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How are NVDA and AMD performing? Any news?",
    "portfolio_code": "P-ALPHA",
    "market_contents": true
  }'

# IBOR-only (no market data)
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Tell me about portfolio composition",
    "portfolio_code": "P-ALPHA",
    "market_contents": false
  }'
```

### Positions Endpoint

```bash
# Get all positions as-of a date
curl -X POST http://localhost:8000/analyst/positions \
  -H "Content-Type: application/json" \
  -d '{
    "portfolio_code": "P-ALPHA",
    "as_of": "2026-03-19"
  }'

# Get positions in a specific account
curl -X POST http://localhost:8000/analyst/positions \
  -H "Content-Type: application/json" \
  -d '{
    "portfolio_code": "P-ALPHA",
    "as_of": "2026-03-19",
    "account_code": "ACCT-PRIME"
  }'
```

### Trades Endpoint

```bash
# Get transaction history for a specific instrument
curl -X POST http://localhost:8000/analyst/trades \
  -H "Content-Type: application/json" \
  -d '{
    "portfolio_code": "P-ALPHA",
    "instrument_code": "EQ-AAPL",
    "as_of": "2026-03-19"
  }'
```

### Prices Endpoint

```bash
# Get price history time series
curl -X POST http://localhost:8000/analyst/prices \
  -H "Content-Type: application/json" \
  -d '{
    "instrument_code": "EQ-AAPL",
    "from_date": "2026-01-01",
    "to_date": "2026-03-19"
  }'
```

### P&L Endpoint

```bash
# Calculate P&L delta between two dates
curl -X POST http://localhost:8000/analyst/pnl \
  -H "Content-Type: application/json" \
  -d '{
    "portfolio_code": "P-ALPHA",
    "as_of": "2026-03-19",
    "prior": "2026-03-18"
  }'
```

### Health Checks

```bash
# FastAPI health
curl http://localhost:8000/health

# Spring Boot health
curl http://localhost:8080/health

# PostgreSQL (if exposed)
psql -h localhost -U postgres -d ibor -c "SELECT 1"
```

</details>

---

## Next Steps - The Unified Vision

### What We've Achieved in Phase 1

IBOR Analyst launched with **RAG-powered conversation memory**:
- ✅ Multi-turn conversations with semantic understanding (pgvector embeddings)
- ✅ Context-aware responses that maintain analyst discussion history
- ✅ Octopus fan-out pattern for parallel IBOR + market data fetching
- ✅ Claude Sonnet 4.6 synthesis of data + market context into analyst prose

### What's Coming in Phase 2

Phase 2 extends the RAG layer to **user-uploaded documents**:
- 🔮 Document upload (regulatory filings, earnings reports, research notes, market commentary)
- 🔮 Semantic embedding of documents alongside conversation history
- 🔮 Unified search: conversations + documents + IBOR data + market context
- 🔮 Answers that blend all four sources into cohesive analyst narratives

### The Vision: A Unified Intelligence Layer

By Phase 2 completion, IBOR Analyst will synthesize:
- **Deterministic data** (IBOR from PostgreSQL) — ground truth
- **Market intelligence** (Yahoo Finance, real-time) — current context
- **Conversational memory** (pgvector, Phase 1) -> analyst discussion
- **Document knowledge** (user uploads, pgvector, Phase 2) - analyst research

All blended by Claude into analyst-grade prose that sounds human, stays grounded in facts, and adapts to evolving analytical needs.
