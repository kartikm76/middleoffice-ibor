# Scripts

Run these four scripts **in order** to bring up the full IBOR platform from a cold start.

---

## Sequence

```
1_infra_start.sh
      ↓
2_data_bootstrap.sh
      ↓
3_services_start.sh
      ↓
4_smoke_test.sh
```

---

## 1 — Infrastructure Start

**What it does:** Starts Colima (Docker runtime) and the PostgreSQL container. Waits until the database is ready to accept connections.

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

**What it does:** Applies the 7 SQL schema scripts (`db/init/01_*.sql` → `07_*.sql`), loads all CSV seed data into staging tables, then promotes staging → curated tables via `ibor.run_all_loaders()`.

Skips automatically if data is already loaded. Use `--force` to drop and reload.

```bash
./scripts/2_data_bootstrap.sh           # skip if already loaded
./scripts/2_data_bootstrap.sh --force   # drop and reload everything
```

Expected output:
```
✓ dim_instrument:          7 instruments
✓ fact_position_snapshot:  3 position rows
✓ fact_price:              4 price rows
✓ fact_trade:              3 trade rows
```

---

## 3 — Services Start

**What it does:** Starts the Spring Boot service (`:8080`) and the Python AI Gateway (`:8000`). Waits for both to be healthy, then pings every endpoint to confirm each one is reachable.

```bash
./scripts/3_services_start.sh
```

Expected output:
```
✓ Spring Boot health         GET  /actuator/health
✓ Spring Boot positions      GET  /api/positions?...
✓ Spring Boot prices         GET  /api/prices/EQ-AAPL?...
✓ AI Gateway health          GET  /health
✓ AI Gateway positions       POST /analyst/positions
✓ AI Gateway trades          POST /analyst/trades
✓ AI Gateway prices          POST /analyst/prices
✓ AI Gateway pnl             POST /analyst/pnl
✓ AI Gateway chat            POST /analyst/chat

  Spring Boot  →  http://localhost:8080/swagger-ui.html
  AI Gateway   →  http://localhost:8000/docs
```

Spring Boot logs: `.spring-boot.log`
AI Gateway logs: `.gateway.log`

---

## 4 — Smoke Test

**What it does:** Runs all 14 curl commands against real endpoints and prints the full JSON response alongside pass/fail for each. Includes expected values so you can verify the data is correct — not just that the service is responding.

```bash
./scripts/4_smoke_test.sh
```

Endpoints tested:

| # | Service | Method | Endpoint | Expected |
|---|---------|--------|----------|---------|
| 1 | Spring Boot | GET | `/actuator/health` | `{"status":"UP"}` |
| 2 | Spring Boot | GET | `/api/positions?portfolioCode=P-ALPHA&asOf=2025-02-04` | EQ-IBM short + FUT-ESZ5 long |
| 3 | Spring Boot | GET | `/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03` | 5 positions |
| 4 | Spring Boot | GET | `/api/prices/EQ-AAPL?from=2025-01-01&to=2025-01-31` | 1 price point at 198.12 |
| 5 | Spring Boot | GET | `/api/positions/P-ALPHA/EQ-IBM?asOf=2025-02-04` | BUY T-0001 + ADJUST |
| 6 | AI Gateway | GET | `/health` | `{"status":"ok"}` |
| 7 | AI Gateway | POST | `/analyst/positions` | totalMarketValue 258510 |
| 8 | AI Gateway | POST | `/analyst/positions` | 5 positions at 2025-01-03 |
| 9 | AI Gateway | POST | `/analyst/trades` | BUY 100 @ 170 + ADJUST -10 |
| 10 | AI Gateway | POST | `/analyst/prices` | min/max/last 198.12 |
| 11 | AI Gateway | POST | `/analyst/pnl` | delta 231079 |
| 12 | AI Gateway | POST | `/analyst/chat` | AI answer about positions |
| 13 | AI Gateway | POST | `/analyst/chat` | AI answer about P&L |
| 14 | AI Gateway | POST | `/analyst/chat` | AI answer about prices |

---

## Seed Data Reference

All test data is for portfolio **P-ALPHA**.

| Instrument | Type | Position dates |
|-----------|------|---------------|
| EQ-IBM | Equity | 2025-01-03 (long 100), 2025-02-04 (short 10 after adjustment) |
| EQ-AAPL | Equity | 2025-01-03 (long 50) |
| FUT-ESZ5 | Futures | 2025-02-04 (long 1 contract) |
| BOND-UST10 | Bond | 2025-01-03 |
| OPT-AAPL-20250117-150C | Option | 2025-01-03 |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Colima is not running` | `colima start` |
| `PostgreSQL not ready` | `docker-compose up -d` then wait ~10s |
| `Data not found (empty [])` | `./scripts/2_data_bootstrap.sh --force` |
| `Spring Boot won't start` | Check Java version: needs Java 21+. See `.spring-boot.log` |
| `AI Gateway 401 Unauthorized` | Regenerate OpenAI key and update `ai-gateway/.env` |
| `AI Gateway won't start` | Check `ai-gateway/.env` exists with `OPENAI_API_KEY`. See `.gateway.log` |
