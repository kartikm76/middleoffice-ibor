#!/usr/bin/env bash
# start.sh — bring up the full IBOR stack
# Usage: ./start.sh [--skip-data]   (--skip-data skips ETL if DB already loaded)

set -euo pipefail

SKIP_DATA=false
[[ "${1:-}" == "--skip-data" ]] && SKIP_DATA=true

ROOT="$(cd "$(dirname "$0")" && pwd)"
JAVA_HOME_CMD="$(/usr/libexec/java_home -v 23 2>/dev/null || /usr/libexec/java_home -v 21 2>/dev/null)"
SPRING_PORT=8080
GATEWAY_PORT=8000
SPRING_LOG="$ROOT/.spring-boot.log"
GATEWAY_LOG="$ROOT/.gateway.log"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
fail() { echo -e "${RED}  ✗ $*${NC}"; exit 1; }
info() { echo -e "${YELLOW}==> $*${NC}"; }

wait_http() {
    local url="$1" label="$2" timeout="${3:-60}"
    local i=0
    while ! curl -sf "$url" > /dev/null 2>&1; do
        sleep 2; i=$((i+2))
        [[ $i -ge $timeout ]] && fail "$label did not become healthy after ${timeout}s"
        echo -n "."
    done
    echo ""
    ok "$label is healthy"
}

# ── 1. Colima ──────────────────────────────────────────────────────────────────
info "Checking Colima..."
if ! colima status 2>/dev/null | grep -q "running"; then
    info "Starting Colima..."
    colima start
    sleep 3
fi
ok "Colima running"

# ── 2. PostgreSQL ──────────────────────────────────────────────────────────────
info "Checking PostgreSQL container..."
cd "$ROOT"
STATUS=$(docker-compose ps -q postgres 2>/dev/null || true)
if [[ -z "$STATUS" ]]; then
    info "Starting PostgreSQL..."
    docker-compose up -d
fi

# Wait for healthy
info "Waiting for PostgreSQL to be healthy..."
i=0
until docker exec docker-postgres-1 pg_isready -U ibor -d ibor -q 2>/dev/null; do
    sleep 2; i=$((i+2))
    [[ $i -ge 60 ]] && fail "PostgreSQL did not become ready after 60s"
    echo -n "."
done
echo ""
ok "PostgreSQL healthy at :5432"

# ── 3. Load data ───────────────────────────────────────────────────────────────
if [[ "$SKIP_DATA" == false ]]; then
    ROWCOUNT=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc \
        "SELECT COUNT(*) FROM ibor.fact_position_snapshot" 2>/dev/null || echo "0")
    if [[ "${ROWCOUNT:-0}" -gt 0 ]]; then
        ok "Data already loaded ($ROWCOUNT position rows) — skipping ETL (use --skip-data to suppress this check)"
    else
        info "Loading schema and seed data..."
        bash "$ROOT/load_all.sh" full
        ok "ETL complete"
    fi
else
    ok "Skipping ETL (--skip-data)"
fi

# ── 4. Spring Boot ─────────────────────────────────────────────────────────────
info "Checking Spring Boot..."
if curl -sf "http://localhost:${SPRING_PORT}/actuator/health" > /dev/null 2>&1; then
    ok "Spring Boot already running at :${SPRING_PORT}"
else
    info "Starting Spring Boot (log → $SPRING_LOG)..."
    JAVA_HOME="$JAVA_HOME_CMD" mvn -f "$ROOT/ibor-server/pom.xml" spring-boot:run \
        > "$SPRING_LOG" 2>&1 &
    SPRING_PID=$!
    echo "  PID: $SPRING_PID"
    info "Waiting for Spring Boot..."
    wait_http "http://localhost:${SPRING_PORT}/actuator/health" "Spring Boot :${SPRING_PORT}" 120
fi

# ── 5. AI Gateway ──────────────────────────────────────────────────────────────
info "Checking AI Gateway..."
if curl -sf "http://localhost:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
    ok "AI Gateway already running at :${GATEWAY_PORT}"
else
    if [[ ! -f "$ROOT/ai-gateway/.env" ]]; then
        fail "ai-gateway/.env not found — copy .env.example and set OPENAI_API_KEY"
    fi
    info "Starting AI Gateway (log → $GATEWAY_LOG)..."
    cd "$ROOT/ai-gateway"
    uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port "$GATEWAY_PORT" \
        > "$GATEWAY_LOG" 2>&1 &
    GATEWAY_PID=$!
    echo "  PID: $GATEWAY_PID"
    info "Waiting for AI Gateway..."
    wait_http "http://localhost:${GATEWAY_PORT}/health" "AI Gateway :${GATEWAY_PORT}" 60
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  IBOR Platform is ready${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  PostgreSQL  :5432"
echo "  Spring Boot :${SPRING_PORT}  →  http://localhost:${SPRING_PORT}/swagger-ui.html"
echo "  AI Gateway  :${GATEWAY_PORT}  →  http://localhost:${GATEWAY_PORT}/docs"
echo ""
echo "  Run ./test.sh to verify all endpoints"
echo ""
