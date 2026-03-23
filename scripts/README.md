# Scripts

Run these four scripts **in order** to bring up the full IBOR platform from a cold start.

---

## Sequence

```
1_infra_start.sh
      ↓
2_data_bootstrap.sh   (calls data_etl.sh internally)
      ↓
3_services_start.sh
      ↓
4_smoke_test.sh
```

---

## 1 — Infrastructure Start

**What it does:** Starts Colima (Docker runtime) and the PostgreSQL + pgvector container.
Waits until the database is ready to accept connections.

```bash
./scripts/1_infra_start.sh
```

Expected output:
```
✓ Colima running
✓ PostgreSQL ready at localhost:5432
```

---

## 2 — Data Bootstrap

**What it does:** Calls `scripts/data_etl.sh full` which runs three phases in sequence:

1. **init_infra** — applies all 6 SQL scripts (`ibor-db/init/01_*.sql` to `06_*.sql`):
   DROP/CREATE schemas, all dim/fact tables, staging tables, loader functions, helpers, views
2. **load_staging** — COPYs all 23 CSVs into `stg.*` tables using `db/data/stg_mapping.json`
3. **load_main** — calls `ibor.run_all_loaders()` which promotes `stg.*` to `ibor.*` dims and facts,
   then clears staging rows

Skips automatically if data is already loaded. Use `--force` to drop and reload everything.

```bash
./scripts/2_data_bootstrap.sh           # skip if already loaded
./scripts/2_data_bootstrap.sh --force   # drop and reload everything
```

Expected output:
```
  dim_instrument:          201 instruments
  fact_position_snapshot:  204 position rows
  fact_price:             1580 price rows
  fact_trade:               61 trade rows
```

**To run ETL directly (without the idempotency wrapper):**

```bash
./scripts/data_etl.sh full           # init + staging + curated in one shot
./scripts/data_etl.sh init_infra     # schema only
./scripts/data_etl.sh load_staging   # CSVs -> stg.* only
./scripts/data_etl.sh load_main      # stg.* -> ibor.* only
```

`data_etl.sh` resolves all paths relative to the repo root, so it works correctly
regardless of which directory you call it from.

---

## 3 — Services Start

**What it does:** Starts Spring Boot (`:8080`) and the Python AI Gateway (`:8000`).
Waits for both to be healthy, then pings key endpoints to confirm they are reachable.

```bash
./scripts/3_services_start.sh
```

Expected output:
```
  Spring Boot  ->  http://localhost:8080/swagger-ui.html
  AI Gateway   ->  http://localhost:8000/docs
```

Spring Boot logs: `.spring-boot.log`
AI Gateway logs: `.gateway.log`

**Java version note:** Spring Boot requires Java 21+. The build uses Java 23 on this machine.

```bash
JAVA_HOME=$(/usr/libexec/java_home -v 23) mvn spring-boot:run
```

**AI Gateway:**

```bash
cd ibor-ai-gateway
PYTHONPATH=src .venv/bin/python3 -m uvicorn ai_gateway.main:app \
  --host 127.0.0.1 --port 8000 --reload
```

---

## 4 — Smoke Test

```bash
./scripts/4_smoke_test.sh
```

| # | Service | Method | Endpoint | What it checks |
|---|---------|--------|----------|----------------|
| 1 | Spring Boot | GET | `/actuator/health` | status UP |
| 2 | Spring Boot | GET | `/api/positions?portfolioCode=P-ALPHA&asOf=2026-03-19` | 50 positions |
| 3 | Spring Boot | GET | `/api/prices/EQ-AAPL` | real yfinance prices |
| 4 | Spring Boot | GET | `/api/positions/P-ALPHA/EQ-AAPL?asOf=2026-03-20` | trade drilldown |
| 5 | AI Gateway | GET | `/health` | status ok |
| 6 | AI Gateway | POST | `/analyst/positions` | totalMarketValue ~$34.5M |
| 7 | AI Gateway | POST | `/analyst/prices` | 8 price points for EQ-NVDA |
| 8 | AI Gateway | POST | `/analyst/pnl` | YTD delta |
| 9 | AI Gateway | POST | `/analyst/chat` | Octopus AI answer with live market data |

---

## data_etl.sh Reference

`data_etl.sh` is the canonical ETL entry point. `2_data_bootstrap.sh` calls it internally.

```
scripts/data_etl.sh <mode>

Modes:
  init_infra   -- Apply ibor-db/init/01 through 06 SQL scripts
  load_staging -- COPY all CSVs in stg_mapping.json into stg.*
  load_main    -- Run ibor.run_all_loaders() to promote stg.* -> ibor.*
  full         -- init_infra + load_staging + load_main
```

**CSV -> stg.* -> ibor.* pipeline (23 CSVs, all ibor.* dims/facts):**

| CSV File | Staging Table | Curated Table |
|----------|--------------|---------------|
| stg_currency.csv | stg.currency | ibor.dim_currency |
| stg_exchange.csv | stg.exchange | ibor.dim_exchange |
| stg_price_source.csv | stg.price_source | ibor.dim_price_source |
| stg_strategy.csv | stg.strategy | ibor.dim_strategy |
| stg_portfolio.csv | stg.portfolio | ibor.dim_portfolio |
| stg_portfolio_strategy.csv | stg.portfolio_strategy | ibor.dim_portfolio_strategy |
| stg_account.csv | stg.account | ibor.dim_account |
| stg_account_portfolio.csv | stg.account_portfolio | ibor.dim_account_portfolio |
| stg_instrument.csv | stg.instrument | ibor.dim_instrument |
| stg_instrument_equity.csv | stg.instrument_equity | ibor.dim_instrument_equity |
| stg_instrument_bond.csv | stg.instrument_bond | ibor.dim_instrument_bond |
| stg_instrument_futures.csv | stg.instrument_futures | ibor.dim_instrument_futures |
| stg_instrument_options.csv | stg.instrument_options | ibor.dim_instrument_options |
| stg_price.csv | stg.price | ibor.fact_price |
| stg_fx_rate.csv | stg.fx_rate | ibor.fact_fx_rate |
| stg_trade_fill.csv | stg.trade_fill | ibor.fact_trade |
| stg_position_snapshot.csv | stg.position_snapshot | ibor.fact_position_snapshot |
| stg_cash_event.csv | stg.cash_event | ibor.fact_cash_event |
| stg_position_adjustment.csv | stg.position_adjustment | ibor.fact_position_adjustment |
| stg_broker.csv | stg.broker | (reference) |
| stg_counterparty.csv | stg.counterparty | (reference) |
| stg_calendar.csv | stg.calendar | (reference) |
| stg_corporate_action_applied.csv | stg.corporate_action_applied | ibor.fact_corporate_action_applied |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Colima is not running` | `colima start` |
| `PostgreSQL not ready` | `docker compose up -d` then wait ~10s |
| `Data not found (empty [])` | `./scripts/2_data_bootstrap.sh --force` |
| `Spring Boot won't start` | Needs Java 21+. Use `JAVA_HOME=$(/usr/libexec/java_home -v 23) mvn spring-boot:run` |
| `AI Gateway missing key error` | Check `ibor-ai-gateway/.env` has `ANTHROPIC_API_KEY=sk-ant-...` |
| `Positions return only 1 row` | asOf date has no snapshot -- uses latest-on-or-before logic |
