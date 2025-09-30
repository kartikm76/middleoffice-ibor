# IBOR Hybrid RAG Starter (Spring Boot + Postgres + pgvector + LangChain4j + Angular)

A reference implementation for an **IBOR** (Investment Book of Record) assistant that answers questions using:

- **Structured facts** (Postgres relational tables: trades/positions/prices/cash)
- **RAG context** (PM notes & external commentary, embedded with OpenAI and stored in **pgvector**)
- An **LLM** (OpenAI) that composes both: *“real-time numbers from SQL + explanations from notes”*

This README covers: architecture, class-by-class overview, Docker setup for Postgres + pgvector + schema/seed SQL, how to run, sample cURL tests, and Swagger/OpenAPI docs.

---

## High-level Architecture
````
User → Controllers → (StructuredService + RagService)
|                    |
|                    +— pgvector (rag_chunks), rag_documents
|
+— Postgres (trades, instruments, portfolios, cash_events…)
↑
Kafka/ETL/External Sources (Phase 2)
````

---
- **StructuredService**: pulls **facts** (qty, MV, cash projections) from SQL.
- **RagService**: manages **notes**, embeddings, pgvector search.
- **Assistant** (LangChain4j): composes an answer using STRUCTURED facts + RAG context.

---

## Tech & Pre-Requisites

- Java 21+ (tested with Java 23)
- Spring Boot 3.5.x (Servlet/MVC)
- Postgres 16 + **pgvector**
- Maven 3.9+
- OpenAI API key
---

## Inital Setup
chmod +x db-rebuild.sh db-apply-sql.sh db-apply-init.sh

# rebuild (DESTROYS data volume)
./db-rebuild.sh

# apply all init scripts from ./docker/init to running container
./db-apply-init.sh

# apply specific files
./db-apply-sql.sh docker/init/01_schema.sql docker/init/02_seed.sql docker/init/03_analytics_seed.sql
# or any arbitrary SQL
./db-apply-sql.sh patches/add_index.sql

## Configuration
`src/main/resources/application.yml` (minimal):

```yaml
server:
  port: 8080

spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/ibor
    username: postgres
    password: postgres
  jpa:
    hibernate:
      ddl-auto: none
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
    open-in-view: false

openai:
  api-key: ${OPENAI_API_KEY}
  baseUrl: https://api.openai.com/v1
  chatModel: gpt-4o-mini
  embedModel: text-embedding-3-small
```
## Docker: Postgres + pgvector + schema/seed
````
docker/
    docker-compose.yml
    db/
        01_schema.sql
        02_seed.sql
````
- 01_schema.sql: creates tables, types, extensions (pgvector).
- 02_seed.sql: inserts dummy instruments, portfolios, trades, cash events, and sample notes.
---
## Docker-compose.yml (example)
````
services:
  db:
    image: pgvector/pgvector:pg16
    container_name: ibor_db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ibor
    ports:
      - "5432:5432"
    volumes:
      - ./db:/docker-entrypoint-initdb.d:ro
      - ibor_pg_data:/var/lib/postgresql/data
volumes:
  ibor_pg_data:
````
`Using pgvector/pgvector:pg16 enables CREATE EXTENSION vector; during init.`

---

# First-time Setup
Option A — clean slate (drop data volume):
````
docker compose down -v
docker compose up -d
docker logs -f ibor_db
````
Option B — reapply in place:
````
docker exec -it ibor_db psql -U postgres -d ibor -c "CREATE EXTENSION IF NOT EXISTS vector;"
docker exec -it ibor_db psql -U postgres -d ibor -f /docker-entrypoint-initdb.d/01_schema.sql
docker exec -it ibor_db psql -U postgres -d ibor -f /docker-entrypoint-initdb.d/02_seed.sql
````
Run the Spring Boot server
````
mvn -q clean package
java -jar target/ibor-server-*.jar
````
# Packages & Classes (what each does)
````
Domain (Entities)
• Instrument — Canonical security (ticker, assetClass, currency, price/time).
• Portfolio — Portfolio master (code).
• Trade — Executions per instrument/portfolio; basis for positions.
• CashEvent — Cash movements; used for forward cash projection.
• RagDocument — Note metadata (UUID doc_id), instrument/portfolio links (INT[]), meta JSON.
• RagChunk — Document chunk with embedding vector for pgvector search.

Repositories
• InstrumentRepository — find by ticker.
• PortfolioRepository — find by code.
• RagDocumentRepository — CRUD on notes metadata.
• RagChunkRepository —
        • insertChunkWithVector(...) (native insert + ::vector cast)
        • search(...) (vector similarity with optional instrument/portfolio filters)
• CashEventRepository — projection for forward cash by date/ccy.

Services
• StructuredService
        • SQL/JPA-only facts (positions, prices, MV, cash projection).
• RagService (OpenAiClient-free)
        • Embeds text using LangChain4j OpenAiEmbeddingModel.
        • Saves document + chunk in a transaction (native insert writes the vector).
        • Searches with vector similarity + filters, returns row-shaped maps.

AI Wiring
• Assistant (interface) — LangChain4j annotated interface with your system prompt (rules: numbers must come from Structured; RAG for “why”; list outputs; tools return lists of rows).
• OpenAiConfig (@Configuration) — Builds:
• OpenAiChatModel (chat), OpenAiEmbeddingModel (embeddings),
• Assistant bean via AiServices.builder(...).chatModel(chatModel).tools(positionTools)....

LangChain Tools
• PositionTools — Exposes StructuredService methods as tools (getPosition, getCashProjection). Always returns List<Map<String,Object>> so the LLM gets consistent shapes.

Web (Controllers)
• NotesController
    • POST /api/notes/ingest → save a note and its embedding.
• RagController
    • POST /api/rag/search → vector search only (top chunks).
    • POST /api/rag/hybrid → build STRUCTURED facts + CONTEXT (RAG) + GAPS, call assistant.chat(...).
    • POST /api/rag/assistant → ask the LLM directly (tools available).
• StructuredController(s)
    • GET /api/structured/position (by ticker)
    • POST /api/structured/cash-projection (by portfolios, days)
````
# cURL tests (end-to-end)
Ingest a PM note
```
curl -s -X POST http://localhost:8080/api/notes/ingest \
  -H "Content-Type: application/json" \
  -d '{
        "title": "IBM thesis",
        "author": "PM",
        "text": "AI infra tailwinds; watch FCF. Cloud margin compression near term.",
        "instrumentTickers": ["IBM"],
        "portfolioCodes": ["ALPHA"]
      }' | jq
```
Pure structured position (IBM)
```
curl -s "http://localhost:8080/api/structured/position?tickerOrId=IBM" | jq
```
Vector search (RAG only)
```
curl -s -X POST http://localhost:8080/api/rag/search \
-H "Content-Type: application/json" \
-d '{ "query":"IBM margins", "instrumentTickers":["IBM"], "topK":3 }' | jq
```
Hybrid answer (STRUCTURED + RAG + LLM)
```
curl -s -X POST http://localhost:8080/api/rag/hybrid \
  -H "Content-Type: application/json" \
  -d '{
        "question":"How does my IBM position look and why?",
        "instrumentTicker":"IBM",
        "portfolioCodes":["ALPHA"],
        "topK":3
      }' | jq
```
Cash projection (next 7 days)
```
curl -s -X POST http://localhost:8080/api/structured/cash-projection \
  -H "Content-Type: application/json" \
  -d '{ "portfolioCodes":["ALPHA"], "days":7 }' | jq
```
