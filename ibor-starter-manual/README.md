# IBOR Bootstrap — Manual/Local Path

This directory contains all scripts for **local development without Docker** (or for debugging).

Used for:
- Local Java + Python development (run services in terminals)
- Debugging and iterating on source code
- Manual database operations

---

## Quick Start — Automated (All Services)

```bash
bash start_all.sh
```

This script:
1. ✓ Starts PostgreSQL in Docker
2. ✓ Waits for bootstrap to load schema + CSV data
3. ✓ Starts Spring Boot (compiles automatically)
4. ✓ Starts Python FastAPI gateway
5. ✓ Starts React UI (Vite dev server)

Then access:
- **Spring Boot**: http://localhost:8080/swagger-ui.html
- **FastAPI**: http://localhost:8000/docs
- **React UI**: http://localhost:5173

Logs are written to:
- `.spring-boot.log` — Spring Boot output
- `.gateway.log` — FastAPI output
- `.ui.log` — React output

**To stop everything:**
```bash
bash stop_all.sh
```

---

## Quick Start — Manual (Separate Terminals, Recommended for Development)

Start services in separate terminals for real-time debugging and fast iteration:

### Step 1: Start Postgres in Docker (Terminal 0)

```bash
cd ibor-analyst
docker-compose up -d postgres bootstrap
```

Wait for bootstrap to complete:
```bash
docker logs ibor-bootstrap | tail -20
```

### Step 2: Start Spring Boot (Terminal 1)

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
cd ibor-middleware
mvn spring-boot:run
```

Available at: http://localhost:8080/swagger-ui.html

### Step 3: Start Python Gateway (Terminal 2)

```bash
cd ibor-ai-gateway
export ANTHROPIC_API_KEY=sk-ant-your-key-here
uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port 8000 --reload
```

Available at: http://localhost:8000/docs

### Step 4: Start React UI (Terminal 3)

```bash
cd ibor-ui
npm run dev
```

Available at: http://localhost:5173

**To stop all services:**
```bash
bash stop_all.sh
```

---

## Alternative: Wrapper Script (Experimental)

We also support `start_all.sh` as a single convenience script:

```bash
./start_all.sh
```

This runs all services in the background. Check logs:
```bash
tail -f .spring-boot.log
tail -f .gateway.log
```

---

## Database Initialization

### Fresh Setup

If Postgres is already running but tables are empty:

```bash
./2_data_bootstrap.sh --force
```

This:
1. Calls `data_etl.sh full` internally
2. Drops and recreates all schemas
3. Loads all CSV files

### Skip If Data Exists

```bash
./2_data_bootstrap.sh
```

Idempotent — only initializes if data is not already loaded.

---

## ETL Pipeline (data_etl.sh)

Direct ETL tool for manual runs. Modes:

```bash
./data_etl.sh full           # init + staging + curated in one shot
./data_etl.sh init_infra     # schema only
./data_etl.sh load_staging   # CSVs -> stg.* only
./data_etl.sh load_main      # stg.* -> ibor.* only
```

### Example: Reload All Data

```bash
./data_etl.sh init_infra
./data_etl.sh load_staging
./data_etl.sh load_main
```

---

## Files Reference

| File | Purpose | Called By |
|------|---------|-----------|
| `1_infra_start.sh` | Legacy: Start Docker infrastructure | Deprecated (use docker-compose) |
| `2_data_bootstrap.sh` | Wrapper that calls `data_etl.sh full` | You (manually) |
| `3_services_start.sh` | Legacy: Start local services in background | Deprecated (use separate terminals) |
| `data_etl.sh` | Core ETL tool — applies SQL + loads CSVs | Called by `2_data_bootstrap.sh` or directly |
| `start_all.sh` | Experimental wrapper to start all services | You (optional, use separate terminals recommended) |

---

## Recommended Workflow

**For development iterating on code:**

1. Start Postgres + bootstrap once:
   ```bash
   docker-compose up -d postgres bootstrap
   ```

2. In separate terminals, start each service with `--reload` enabled:
   - Spring Boot: `mvn spring-boot:run` (auto-recompiles on changes)
   - Python: `uvicorn ... --reload` (auto-reloads on changes)
   - React: `npm run dev` (auto-rebuilds on changes)

3. **Do not** use the wrapper scripts for active development — they make debugging harder

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Database connection refused` | Check Postgres is running: `docker ps` |
| `Data not loaded` | Run `./2_data_bootstrap.sh --force` |
| `Spring Boot won't start` | Needs Java 21+: `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` |
| `Python dependency missing` | Install: `cd ibor-ai-gateway && uv sync` |
| `React won't compile` | Install: `cd ibor-ui && npm install` |

---

## Common Queries

### What's the difference between 2_data_bootstrap.sh and data_etl.sh?

- `2_data_bootstrap.sh` - Wrapper that calls `data_etl.sh full` with idempotency checks
- `data_etl.sh` - Direct tool with more control (init_infra, load_staging, load_main modes)

Use `2_data_bootstrap.sh` for convenience. Use `data_etl.sh` if you need fine-grained control.

### Should I use start_all.sh?

Not for development. It's experimental and makes debugging harder. Instead:
- Run each service in its own terminal with `--reload` enabled
- See logs in real-time
- Restart individual services without affecting others

---

## File Structure

```
ibor-starter-manual/
├── 1_infra_start.sh        # Legacy — don't use
├── 2_data_bootstrap.sh     # Wrapper for data_etl.sh
├── 3_services_start.sh     # Legacy — don't use
├── data_etl.sh             # Core ETL tool
├── start_all.sh            # Experimental wrapper
└── README.md               # This file
```
