#!/usr/bin/env bash
# 1_infra_start.sh — Start Colima and PostgreSQL container
# Run this first before any other script.
#
# Usage: ./scripts/1_infra_start.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
fail() { echo -e "${RED}  ✗ $*${NC}"; exit 1; }
info() { echo -e "${YELLOW}==> $*${NC}"; }

echo -e "\n${YELLOW}[1/4] Infrastructure — Colima + PostgreSQL${NC}\n"

# ── Colima ────────────────────────────────────────────────────────────────────
info "Checking Colima (Docker runtime)..."
if colima status 2>/dev/null | grep -q "running"; then
    ok "Colima already running"
else
    info "Starting Colima..."
    colima start
    sleep 3
    ok "Colima started"
fi

# ── PostgreSQL container ───────────────────────────────────────────────────────
info "Checking PostgreSQL container..."
cd "$ROOT"
if docker-compose ps 2>/dev/null | grep -q "Up"; then
    ok "PostgreSQL container already up"
else
    info "Starting PostgreSQL container..."
    docker-compose up -d
fi

# ── Wait for ready ─────────────────────────────────────────────────────────────
info "Waiting for PostgreSQL to be ready..."
i=0
until docker exec docker-postgres-1 pg_isready -U ibor -d ibor -q 2>/dev/null; do
    sleep 2; i=$((i+2))
    [[ $i -ge 60 ]] && fail "PostgreSQL did not become ready after 60s — check: docker logs docker-postgres-1"
    echo -n "."
done
echo ""
ok "PostgreSQL ready at localhost:5432"

echo ""
echo -e "${GREEN}  Infrastructure is up. Next: run ./scripts/2_data_bootstrap.sh${NC}"
echo ""
