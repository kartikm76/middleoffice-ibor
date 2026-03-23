#!/usr/bin/env bash
# 2_data_bootstrap.sh — Load database schema and seed data
# Requires PostgreSQL to be running (run 1_infra_start.sh first).
#
# Usage:
#   ./scripts/2_data_bootstrap.sh           # skip if data already loaded
#   ./scripts/2_data_bootstrap.sh --force   # drop and reload everything

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
fail() { echo -e "${RED}  ✗ $*${NC}"; exit 1; }
info() { echo -e "${YELLOW}==> $*${NC}"; }

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

echo -e "\n${YELLOW}[2/4] Data Bootstrap — Schema + ETL${NC}\n"

# ── Check DB is reachable ──────────────────────────────────────────────────────
docker exec docker-postgres-1 pg_isready -U ibor -d ibor -q 2>/dev/null \
    || fail "PostgreSQL is not running — run 1_infra_start.sh first"

# ── Skip if already loaded (unless --force) ────────────────────────────────────
if [[ "$FORCE" == false ]]; then
    ROWCOUNT=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc \
        "SELECT COUNT(*) FROM ibor.fact_position_snapshot" 2>/dev/null || echo "0")
    if [[ "${ROWCOUNT:-0}" -gt 0 ]]; then
        ok "Data already loaded ($ROWCOUNT position rows) — skipping"
        echo "    Use --force to drop and reload: ./scripts/2_data_bootstrap.sh --force"
        echo ""
        echo -e "${GREEN}  Next: run ./scripts/3_services_start.sh${NC}"
        echo ""
        exit 0
    fi
fi

# ── Run ETL ────────────────────────────────────────────────────────────────────
info "Running full ETL (schema → staging → curated)..."
bash "$ROOT/scripts/data_etl.sh" full

# ── Verify ────────────────────────────────────────────────────────────────────
info "Verifying loaded data..."

POS=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc \
    "SELECT COUNT(*) FROM ibor.fact_position_snapshot")
INSTR=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc \
    "SELECT COUNT(*) FROM ibor.dim_instrument")
PRICES=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc \
    "SELECT COUNT(*) FROM ibor.fact_price")
TRADES=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc \
    "SELECT COUNT(*) FROM ibor.fact_trade")

ok "dim_instrument:          $INSTR instruments"
ok "fact_position_snapshot:  $POS  position rows"
ok "fact_price:              $PRICES price rows"
ok "fact_trade:              $TRADES trade rows"

echo ""
echo -e "${GREEN}  Data loaded. Next: run ./scripts/3_services_start.sh${NC}"
echo ""
