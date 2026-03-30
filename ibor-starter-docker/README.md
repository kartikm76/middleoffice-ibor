# IBOR Bootstrap — Docker Path

This directory contains everything needed for **Docker-based initialization and deployment**.

Used for:
- Local Docker development (`docker-compose up`)
- Railway/cloud deployment
- Any containerized environment

---

## Quick Start

From the project root:

```bash
bash ibor-starter-docker/start_all.sh
```

This script:
1. Builds all Docker images
2. Starts PostgreSQL with pgvector
3. Runs bootstrap container (loads schema + CSV data)
4. Starts middleware, gateway, and UI services
5. Waits for all services to be healthy

Then access:
- **Spring Boot**: http://localhost:8080/swagger-ui.html
- **FastAPI**: http://localhost:8000/docs
- **React UI**: http://localhost:5173

**To stop everything:**
```bash
bash ibor-starter-docker/stop_all.sh
```

**To stop and delete all data:**
```bash
docker-compose down --volumes
```

**Alternative: Direct Docker**

If you prefer to control docker-compose directly:
```bash
docker-compose up              # Start everything
docker-compose logs -f         # View logs
docker-compose down            # Stop containers (preserve data)
docker-compose down --volumes  # Stop & delete data
```

---

## How It Works

### Architecture: Dockerfile.bootstrap → bootstrap-init.sh

**Dockerfile.bootstrap** (parent — Docker image definition):
- Defines the Docker image that runs the database initialization job
- Base image: `postgres:16-alpine` (includes psql, pg_isready)
- Installs utilities: bash, jq, curl
- **Copies** `ibor-starter-docker/bootstrap-init.sh` into container as `/bootstrap/init.sh`
- **Copies** entire `ibor-db/` directory (SQL scripts + CSV data)
- Sets **ENTRYPOINT** to: `/bin/bash /bootstrap/init.sh`

When the bootstrap container starts (via `docker-compose`), it automatically executes the initialization script.

### `bootstrap-init.sh` (child — initialization script)

Runs inside the bootstrap container. It:

1. **Waits for Postgres** to be healthy (pg_isready)
2. **Checks if data already loaded** (idempotent — skips if data exists)
3. **Applies SQL scripts** from `ibor-db/init/` to create schema
4. **Loads CSV files** from `ibor-db/data/` into staging tables
5. **Promotes data** via `ibor.run_all_loaders()` to curated schema
6. **Validates** that 201 instruments, 204 positions, 1604 prices, 61 trades loaded
7. **Exits** after completion (container stops automatically)

---

## Integration with docker-compose.yml

The `bootstrap` service in `docker-compose.yml`:

```yaml
bootstrap:
  build:
    context: .
    dockerfile: ibor-starter-docker/Dockerfile.bootstrap
  depends_on:
    postgres:
      condition: service_healthy
  restart: "no"  # Runs once, then exits
```

Other services wait for bootstrap to complete:

```yaml
ibor-middleware:
  depends_on:
    bootstrap:
      condition: service_completed_successfully
```

---

## Environment Variables

Set these in `docker-compose.yml` or `.env`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CONTAINER` | `ibor-postgres` | Postgres container name |
| `DB_NAME` | `ibor` | Database name |
| `DB_USER` | `ibor` | Database user |
| `DB_PASSWORD` | `ibor` | Database password |
| `ANTHROPIC_API_KEY` | `sk-ant-placeholder` | For AI gateway (set your key) |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Bootstrap didn't run` | Check `docker logs ibor-bootstrap` |
| `Postgres connection refused` | Wait 30s for Postgres to start |
| `Data not loaded` | Run `docker-compose down --volumes && docker-compose up` |
| `Schema missing` | Bootstrap logs will show SQL errors |

---

## Files Reference

| File | Purpose |
|------|---------|
| `Dockerfile.bootstrap` | Docker image for initialization job |
| `bootstrap-init.sh` | Unified initialization script (schema + CSV loading) |

**No other files in this directory — all manual/legacy scripts are in `ibor-starter-manual/`**
