# IBOR Hybrid Starter (Postgres + pgvector + Spring Boot + Angular)

An opinionated starter for an Investment Book of Record (IBOR) with:
- Relational core (trades, instruments, portfolios, positions, cash, FX)
- pgvector RAG store for notes/documents
- Spring Boot server (hybrid answers: SQL facts + RAG context)
- Optional Angular client

## High-level Architecture
````
User → Controllers → (StructuredService + RagService)
|                    |
|                    +— pgvector (rag_chunks), rag_documents
|
+— Postgres (trades, instruments, portfolios, cash_events…)
↑
Kafka/ETL/External Sources (Phase 2)

---
- **StructuredService**: pulls **facts** (qty, MV, cash projections) from SQL.
- **RagService**: manages **notes**, embeddings, pgvector search.
- **Assistant** (LangChain4j): composes an answer using STRUCTURED facts + RAG context.

---

This README gives you:
- Clear ASCII ER diagram of the curated schema (ibor.*)
- High-level flow from data files → staging → curated → API/LLM
- Quick start commands
- Next steps to integrate with AI (RAG + hybrid answering)

---

## Repository layout
```
middleoffice-ibor/
├ docker/                     # Docker and DB bootstrap
│  └ db/
│     ├ data/                 # Sample CSVs and mapping JSON
│     └ init/                 # SQL: schema, staging, loaders, helpers
├ ibor-server/                # Spring Boot backend (RAG + structured)
├ ibor-client/                # Angular client (optional)
├ load_all.sh                 # Helper: init schemas, load staging CSVs, run loaders
├ docker-compose.yml          # Postgres 16 + pgvector
└ README.md                   # You are here
```
---
## Tech & Pre-Requisites

- Java 21+ (tested with Java 23)
- Spring Boot 3.5.x (Servlet/MVC)
- Postgres 16 + **pgvector**
- Maven 3.9+
- OpenAI API key
---


## Quick start
1) Start Postgres (with pgvector)
```
docker compose up -d
```

2) Initialize schemas (ibor.*, stg.*), helpers and loaders
```
./load_all.sh init_infra
```

3) Load sample CSVs into staging and move them into curated
```
./load_all.sh load_staging
./load_all.sh load_main
```

4) Run the server (see ibor-server/README.md for details)
```
cd ibor-server
mvn -q clean package
java -jar target/ibor-server-*.jar
```

---

## ASCII ER diagram (curated schema: ibor.*)
Legend: [PK] primary key, [FK] foreign key, (SCD2) slowly-changing dimension type 2

```
Reference dimensions (non-SCD)
┌────────────────────────┐      ┌────────────────────────┐      ┌────────────────────────────┐      ┌────────────────────────┐
│ dim_currency           |      │ dim_exchange           │      │ dim_price_source           │      │ dim_strategy           │
│ [PK] currency_vid      │      │ [PK] exchange_vid      │      │ [PK] price_source_vid      │      │ [PK] strategy_vid      │
│     currency_code UQ   │      │     exchange_code UQ   │      │     price_source_code UQ   │      │     strategy_code UQ   │
└────────────────────────┘      └────────────────────────┘      └────────────────────────────┘      └────────────────────────┘

Core dimensions (SCD2)
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ dim_instrument (SCD2)                                                                                                        │
│ [PK] instrument_vid                                                                                                          │
│     instrument_code, instrument_type, instrument_name, exchange_code [FK→dim_exchange], currency_code [FK→dim_currency]      │
│     valid_from, valid_to, is_current                                                                                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
  ├─ 1:1 dim_instrument_equity  (instrument_vid [FK→dim_instrument])
  ├─ 1:1 dim_instrument_bond    (instrument_vid [FK→dim_instrument])
  ├─ 1:1 dim_instrument_futures (instrument_vid [FK→dim_instrument])
  └─ 1:1 dim_instrument_options (instrument_vid [FK→dim_instrument])

┌──────────────────────────────┐      ┌──────────────────────────────┐
│ dim_portfolio (SCD2)         │      │ dim_account (SCD2)           │
│ [PK] portfolio_vid           │      │ [PK] account_vid             │
│     portfolio_code, validity │      │     account_code, validity   │
└──────────────────────────────┘      └──────────────────────────────┘

Bridges (SCD2)
┌─────────────────────────────────────┐      ┌─────────────────────────────────────┐
│ dim_portfolio_strategy (SCD2)       │      │ dim_account_portfolio (SCD2)        │
│ [PK] portfolio_strategy_vid         │      │ [PK] account_portfolio_vid          │
│     portfolio_vid [FK→portfolio]    │      │     account_vid [FK→account]        │
│     strategy_vid  [FK→strategy]     │      │     portfolio_vid [FK→portfolio]    │
│     valid_from..is_current          │      │     valid_from..is_current          │
└─────────────────────────────────────┘      └─────────────────────────────────────┘

Facts
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ fact_price                                                                                                                   │
│ [PK] (instrument_vid, price_source_vid, price_ts)                                                                            │
│     instrument_vid [FK→dim_instrument], price_source_vid [FK→dim_price_source], currency_code [FK→dim_currency]              │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐    ┌─────────────────────────────────────────────┐
│ fact_fx_rate                                 │    │ fact_trade                                  │
│ [PK] (from_currency_code, to_currency_code,  │    │ [PK] execution_id                           │
│      rate_date)                              │    │     account_vid [FK→dim_account]            │
│     from/to currency_code [FK→dim_currency]  │    │     instrument_vid [FK→dim_instrument]      │
└──────────────────────────────────────────────┘    └─────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐   ┌───────────────────────────────────────────────────────────┐
│ fact_position_snapshot                                       │   │ fact_cash_event                                           │
│ [PK] (portfolio_vid, instrument_vid, position_date)          │   │ [PK] (portfolio_vid, event_date, amount)                  │
│     portfolio_vid [FK→dim_portfolio]                         │   │     portfolio_vid [FK→dim_portfolio]                      │
│     instrument_vid [FK→dim_instrument]                       │   │     currency_code [FK→dim_currency]                       │
└──────────────────────────────────────────────────────────────┘   └───────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐      ┌────────────────────────────────────────────────────────┐
│ fact_position_adjustment                                     │      │ fact_corporate_action_applied                          │
│ [PK] position_adjustment_id                                  │      │ [PK] ca_applied_id                                     │
│     portfolio_vid [FK→dim_portfolio]                         │      │     instrument_vid [FK→dim_instrument]                 │
│     instrument_vid [FK→dim_instrument]                       │      │     currency_code [FK→dim_currency] (optional)         │
└──────────────────────────────────────────────────────────────┘      └────────────────────────────────────────────────────────┘

RAG (pgvector)
┌───────────────────────┐   1 ┌─────────┐
│ rag_documents         │─────│         │
│ [PK] document_id      │     │     N   │
└───────────────────────┘       ▼
                             ┌────────────────────┐
                             │ rag_chunks         │
                             │ [PK] chunk_id      │
                             │ document_id [FK]   │
                             │ embedding vector   │
                             └────────────────────┘
```

---

## High-level data and request flow
```
┌───────────────┐     ┌───────────────┐     ┌─────────────────┐     ┌─────────────────────┐
│ CSV/JSON      │ --> │ staging (stg) │ --> │ loaders (SQL)   │ --> │ curated (ibor.*)    │
│ docker/db/... │     │ COPY via      │     │ ibor.run_all_*  │     │ dims, bridges,      │
│               │     │ load_all.sh   │     │ SCD2 + facts    │     │ facts, rag_*        │
└───────────────┘     └───────────────┘     └─────────────────┘     └─────────────────────┘
                                 │                                        │
                                 │                                        ▼
                                 │                          ┌──────────────────────────────┐
                                 │                          │ Spring Boot (ibor-server)    │
                                 │                          │ REST: Structured + RAG       │
                                 │                          └───────────────┬──────────────┘
                                 │                                          │
                                 ▼                                          ▼
                       pgvector similarity                         LLM (OpenAI via LangChain4j)
                       (rag_chunks.embedding)                      Hybrid answers: SQL facts +
                                                                   RAG context from rag_chunks
```

---

## Useful scripts and files
- docker-compose.yml: launches Postgres 16 with pgvector extension
- docker/db/init/*.sql: schema, staging, loaders, helpers
- docker/db/data/*.csv: sample inputs, with mapping in stg_mapping.json
- load_all.sh: one-stop helper
  - init_infra → apply SQL (schemas, functions)
  - load_staging → COPY CSVs to stg.*
  - load_main → run ibor.run_all_loaders() to populate ibor.*

---

## Next steps to integrate with AI
You already have vector-ready tables and a Spring Boot server capable of hybrid answers. To complete AI integration:

1) Configure models and keys
- Set environment variables for ibor-server:
  - OPENAI_API_KEY, and optionally model names (chat/embeddings)

2) Ingest knowledge into RAG
- Use ibor-server endpoints (see ibor-server/README.md) to:
  - POST /api/notes/ingest → embeds and stores into rag_documents + rag_chunks
  - POST /api/rag/search → vector search (similarity)

3) Expose structured tools to the LLM
- StructuredService endpoints already query SQL facts (positions, prices, cash)
- Ensure these are registered as tools for the assistant (LangChain4j)

4) Enable hybrid Q&A
- Use /api/rag/hybrid to compose: structured SQL output + top-K RAG chunks → assistant
- Adjust the system prompt to enforce: “numbers come from SQL; text context from RAG”

5) Hardening and quality
- Add guardrails (schema-constrained tool I/O, row-shape contracts)
- Add caching of embeddings/search if needed
- Tune pgvector index (lists, probes) for your data size

6) Observability
- Log traces per request (SQL + vector search + LLM call)
- Add evaluation sets for regression testing of Q&A

---

## Notes
- All SCD2 tables carry valid_from, valid_to, is_current and are resolved via helper fns (e.g., fn_*_vid_at)
- FX helpers include direct and USD-triangulated pickers
- Audit triggers auto-manage created_at/updated_at on ibor.* and stg.*
