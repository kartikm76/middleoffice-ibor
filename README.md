# IBOR Platform — AI-Powered Investment Book of Record

An Investment Book of Record (IBOR) is the authoritative, real-time view of a portfolio's
holdings — positions, trades, prices, and P&L — used by portfolio managers to make
investment decisions.

This platform pairs deterministic financial data with an AI analyst so you can ask questions
in plain English and get grounded, data-backed answers enriched with live market context.

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

**Core philosophy:** numbers/facts come from SQL, reasoning/narrative come from AI.

---

## How the AI Analyst Works

### The Octopus Fan-Out Pattern

When a portfolio manager asks a question, the AI gateway runs a two-stage orchestration:

**Stage 1 — Intent Parse (LLM call #1)**

Claude reads the question and outputs a structured plan: which IBOR tools to call,
any tickers explicitly named, and whether macro data is relevant.

**Stage 2a — Explicit tickers: True Octopus blast**

If the question names specific tickers (e.g. "compare NVDA and AMD"),
all IBOR fetches and all market data fetches fire simultaneously via `asyncio.gather`:

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

If the question is portfolio-level (e.g. "show me my positions"), IBOR data is fetched
first, equity instrument codes (EQ-AAPL, EQ-NVDA...) are extracted and stripped to bare
tickers, then market data is fetched in a second parallel blast:

```
Question: "What are my top equity positions?"
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

### External Market Data (yfinance)

Four async tools fetch live data from Yahoo Finance, all wrapped with `asyncio.to_thread`
since yfinance is synchronous:

| Tool | What it returns |
|------|----------------|
| `get_market_snapshot(ticker)` | Price, change%, volume, market cap, P/E, 52-week range, analyst target & rating |
| `get_news(ticker)` | Latest 5 headlines with source and timestamp |
| `get_earnings(ticker)` | Next earnings date, forward EPS estimate, trailing EPS |
| `get_macro_snapshot()` | S&P 500 level, VIX, US 10-year Treasury yield |

### Synthesis

Claude Sonnet 4.6 combines IBOR facts + market context into analyst-grade prose:
- IBOR numbers are ground truth — never rounded, estimated, or invented
- Market data adds intelligence (price momentum, news catalysts, earnings risk)
- Response is 4–8 sentences of flowing prose, no bullet points
- Surfaces one key risk or opportunity the PM should act on

---

## Market Data in the Database

Prices in the IBOR are real historical data downloaded from Yahoo Finance, not synthetic:

- **201 instruments**: 121 equities (US mega-cap + European), 25 bonds, 25 futures,
  10 options, 7 FX pairs, 10 indices, 3 ETFs
- **1,580 price rows** across 8 dates (2025-01-02 to 2026-03-20)
- **216 FX rate rows** (7 direct + 3 inverse pairs, same 8 dates)
- **Bond prices** computed from real treasury yields (^IRX, ^FVX, ^TNX, ^TYX) using
  standard bond pricing formula with issuer credit spreads

US equities include: AAPL, MSFT, NVDA, GOOGL, META, AMZN, TSLA, JPM, BAC, GS, JNJ,
UNH, XOM, CVX, BA, SPY, QQQ, GLD, TLT, and 80+ more.

European equities include: SAP (XETR), ASML (XAMS), LVMH (XPAR), NESN (XSWX),
SHEL (XLON), AZN (XLON), and more.

London-listed stocks are stored in GBP (converted from GBX pence at fetch time).
Swiss stocks (NESN, ROG, NOVN) are stored in CHF.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16 + pgvector |
| REST API | Spring Boot 3.5.5, Java 23, jOOQ 3.18.7 |
| AI Gateway | FastAPI 0.119+, Python 3.13, Anthropic SDK |
| LLM | Claude Sonnet 4.6 (claude-sonnet-4-6) |
| Market Data | yfinance 0.2.50+ (Yahoo Finance) |
| Async | asyncio.gather + asyncio.to_thread |

---

## Quick Start

```bash
# 1. Start infra (Colima + PostgreSQL container)
./ibor-starter/1_infra_start.sh

# 2. Load schema + all 23 CSVs + promote to ibor.* tables
./ibor-starter/2_data_bootstrap.sh

# 3. Start Spring Boot + AI Gateway
./ibor-starter/3_services_start.sh

# 4. Verify everything works
./ibor-starter/4_smoke_test.sh
```

Then open:
- Spring Boot Swagger: http://localhost:8080/swagger-ui.html
- AI Gateway docs:    http://localhost:8000/docs

---

## API Endpoints

### Spring Boot (:8080/api)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/positions` | Positions as-of date (uses latest snapshot on-or-before) |
| GET | `/api/positions/{portfolio}/{instrument}` | Trade drilldown for one instrument |
| GET | `/api/positions/composition` | Portfolio composition breakdown |
| GET | `/api/prices/{instrumentCode}` | Price time series |
| GET | `/api/instruments/{instrumentCode}` | Instrument master data |
| GET | `/api/analytics/attribution/brinson/daily` | Brinson attribution (requires analytics schema) |
| GET | `/api/analytics/returns/portfolio` | Portfolio TWRR (requires analytics schema) |

### AI Gateway (:8000/analyst)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/analyst/positions` | Deterministic positions proxy |
| POST | `/analyst/prices` | Deterministic price proxy |
| POST | `/analyst/trades` | Deterministic trades proxy |
| POST | `/analyst/pnl` | P&L delta between two dates |
| POST | `/analyst/chat` | AI analyst — Octopus fan-out + Claude narration |
| GET | `/health` | Health check |

### Chat request format

```bash
curl -X POST http://localhost:8000/analyst/chat \
  -H "Content-Type: application/json" \
  -d '{"question": "What are my top positions in P-ALPHA and how is the market looking?"}'
```

Response structure:
```json
{
  "question": "...",
  "as_of": "2026-03-20",
  "summary": "P-ALPHA carries a total market value of $34.5M ...",
  "data": {
    "ibor": { "positions": [...], "totalMarketValue": 34524750.05 },
    "market": {
      "by_ticker": {
        "AAPL": { "snapshot": {...}, "news": {...}, "earnings": {...} }
      },
      "macro": { "sp500": 6506.48, "vix": 26.78, "us_10y_yield": 4.391 }
    }
  },
  "gaps": []
}
```

- `summary` — Claude's analyst-grade narrative combining IBOR + market context
- `data.ibor` — raw numbers from the database (ground truth)
- `data.market` — live data from Yahoo Finance fetched at query time
- `gaps` — any tools that failed or data that was unavailable

---

## Database Schema

Three schemas in PostgreSQL:

**`ibor.*`** — Curated facts and dimensions (ground truth)
- SCD2 on instruments, portfolios, accounts: `valid_from`, `valid_to`, `is_current`
- Surrogate keys (`*_vid`) used internally; business keys used in APIs
- Key tables: `dim_instrument`, `dim_portfolio`, `dim_account`, `dim_account_portfolio`,
  `fact_price`, `fact_fx_rate`, `fact_position_snapshot`, `fact_trade`, `fact_cash_event`

**`stg.*`** — Staging tables (CSV landing zone, cleared after each ETL run)

**`rag_*`** — pgvector embeddings for semantic RAG (populated in Phase 2)

**Data hierarchy:**
```
dim_portfolio  (P-ALPHA)
      └── dim_account_portfolio  (many-to-many join)
            └── dim_account  (ACCT-PRIME, ACCT-CUSTODY)
```

Positions are stored at portfolio level (`fact_position_snapshot.portfolio_vid`).
Trades are stored at account level (`fact_trade.account_vid`).
Account-level position filtering is a Phase 2 item.

---

## Configuration

**AI Gateway** (`ibor-ai-gateway/`):
- `config.yaml` — non-secret config (model name, API base URL, etc.)
- `.env` — secrets: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` (for RAG embeddings)

**Spring Boot** (`ibor-middleware/`):
- `src/main/resources/application.yml` — DB connection, server port
- `src/main/resources/application-test.yml` — test overrides

---

## ETL Pipeline

```bash
# Full reload from scratch
./ibor-starter/data_etl.sh full

# Individual phases
./ibor-starter/data_etl.sh init_infra     # schema only
./ibor-starter/data_etl.sh load_staging   # CSVs -> stg.*
./ibor-starter/data_etl.sh load_main      # stg.* -> ibor.*
```

See `ibor-starter/README.md` for the full CSV-to-table mapping.

---

## Project Structure

```
ibor-analyst/
├── ibor-middleware/          Spring Boot REST API (Java 23, Maven, jOOQ)
├── ibor-ai-gateway/           FastAPI AI gateway (Python 3.13, uv)
│   ├── src/ai_gateway/
│   │   ├── service/
│   │   │   ├── llm_service.py     Octopus orchestrator (two-stage fan-out)
│   │   │   ├── market_tools.py    yfinance async wrappers
│   │   │   └── ibor_service.py    IBOR data fetcher + IborAnswer builder
│   │   ├── controller/
│   │   │   ├── analyst.py         REST routes
│   │   │   └── health.py
│   │   ├── repository/
│   │   │   └── ibor_repository.py httpx client for Spring Boot
│   │   ├── config/settings.py     YAML + dotenv loader
│   │   └── model/schemas.py       IborAnswer + request/response models
│   ├── config.yaml
│   └── .env
├── db/
│   ├── init/             SQL scripts 01-06 (schema, loaders, helpers, views)
│   └── data/             23 CSV seed files + stg_mapping.json
├── ibor-starter/
│   ├── data_etl.sh       ETL entry point (replaces load_all.sh)
│   ├── 1_infra_start.sh
│   ├── 2_data_bootstrap.sh
│   ├── 3_services_start.sh
│   └── 4_smoke_test.sh
└── docker-compose.yml    PostgreSQL 16 + pgvector container
```
