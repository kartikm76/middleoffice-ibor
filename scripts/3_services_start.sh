#!/usr/bin/env bash
# 3_services_start.sh — Start Spring Boot and AI Gateway, then health-check all endpoints
# Requires data to be loaded (run 2_data_bootstrap.sh first).
#
# Usage: ./scripts/3_services_start.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAVA_HOME_BIN="$(/usr/libexec/java_home -v 23 2>/dev/null || /usr/libexec/java_home -v 21 2>/dev/null)"
SPRING_PORT=8080
GATEWAY_PORT=8000
SPRING_LOG="$ROOT/.spring-boot.log"
GATEWAY_LOG="$ROOT/.gateway.log"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
fail() { echo -e "${RED}  ✗ $*${NC}"; exit 1; }
info() { echo -e "${YELLOW}==> $*${NC}"; }

echo -e "\n${YELLOW}[3/4] Services — Spring Boot + AI Gateway${NC}\n"

wait_http() {
    local url="$1" label="$2" timeout="${3:-90}"
    local i=0
    while ! curl -sf "$url" > /dev/null 2>&1; do
        sleep 2; i=$((i+2))
        [[ $i -ge $timeout ]] && fail "$label not healthy after ${timeout}s — check log"
        echo -n "."
    done
    echo ""
}

# ── Spring Boot ────────────────────────────────────────────────────────────────
info "Checking Spring Boot..."
if curl -sf "http://localhost:${SPRING_PORT}/actuator/health" > /dev/null 2>&1; then
    ok "Spring Boot already running"
else
    info "Starting Spring Boot (log → $SPRING_LOG)..."
    JAVA_HOME="$JAVA_HOME_BIN" mvn -f "$ROOT/ibor-server/pom.xml" \
        spring-boot:run > "$SPRING_LOG" 2>&1 &
    echo "  PID: $!"
    info "Waiting for Spring Boot..."
    wait_http "http://localhost:${SPRING_PORT}/actuator/health" "Spring Boot" 120
    ok "Spring Boot started"
fi

# ── AI Gateway ─────────────────────────────────────────────────────────────────
info "Checking AI Gateway..."
if curl -sf "http://localhost:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
    ok "AI Gateway already running"
else
    [[ -f "$ROOT/ai-gateway/.env" ]] \
        || fail "ai-gateway/.env not found — copy .env.example and set OPENAI_API_KEY"
    info "Starting AI Gateway (log → $GATEWAY_LOG)..."
    cd "$ROOT/ai-gateway"
    uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port "$GATEWAY_PORT" \
        > "$GATEWAY_LOG" 2>&1 &
    echo "  PID: $!"
    info "Waiting for AI Gateway..."
    wait_http "http://localhost:${GATEWAY_PORT}/health" "AI Gateway" 60
    ok "AI Gateway started"
fi

# ── Health check all endpoints ─────────────────────────────────────────────────
echo ""
info "Health checking all endpoints..."

check_endpoint() {
    local label="$1" url="$2"
    if curl -sf "$url" > /dev/null 2>&1; then
        ok "$label"
    else
        echo -e "${RED}  ✗ $label — ${url}${NC}"
    fi
}

check_endpoint "Spring Boot health         GET  /actuator/health"             "http://localhost:${SPRING_PORT}/actuator/health"
check_endpoint "Spring Boot positions      GET  /api/positions?..."           "http://localhost:${SPRING_PORT}/api/positions?portfolioCode=P-ALPHA&asOf=2025-02-04"
check_endpoint "Spring Boot prices         GET  /api/prices/EQ-AAPL?..."      "http://localhost:${SPRING_PORT}/api/prices/EQ-AAPL?from=2025-01-01&to=2025-01-31"
check_endpoint "AI Gateway health          GET  /health"                      "http://localhost:${GATEWAY_PORT}/health"

# POST endpoints need -X POST
check_post() {
    local label="$1" url="$2" body="$3"
    if curl -sf -X POST "$url" -H "Content-Type: application/json" -d "$body" > /dev/null 2>&1; then
        ok "$label"
    else
        echo -e "${RED}  ✗ $label — ${url}${NC}"
    fi
}

check_post "AI Gateway positions       POST /analyst/positions"           "http://localhost:${GATEWAY_PORT}/analyst/positions" '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04"}'
check_post "AI Gateway trades          POST /analyst/trades"              "http://localhost:${GATEWAY_PORT}/analyst/trades"    '{"portfolio_code":"P-ALPHA","instrument_code":"EQ-IBM","as_of":"2025-02-04"}'
check_post "AI Gateway prices          POST /analyst/prices"              "http://localhost:${GATEWAY_PORT}/analyst/prices"    '{"instrument_code":"EQ-AAPL","from_date":"2025-01-01","to_date":"2025-01-31"}'
check_post "AI Gateway pnl             POST /analyst/pnl"                 "http://localhost:${GATEWAY_PORT}/analyst/pnl"       '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04","prior":"2025-01-03"}'
check_post "AI Gateway chat            POST /analyst/chat"                "http://localhost:${GATEWAY_PORT}/analyst/chat"      '{"question":"What are the positions in P-ALPHA as of 2025-02-04?"}'

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  All services are up${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Spring Boot  →  http://localhost:${SPRING_PORT}/swagger-ui.html"
echo "  AI Gateway   →  http://localhost:${GATEWAY_PORT}/docs"
echo ""
echo -e "${GREEN}  Next: run ./scripts/4_smoke_test.sh for full business data verification${NC}"
echo ""
