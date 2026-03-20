#!/usr/bin/env bash
# test.sh — smoke test every IBOR endpoint
# Usage: ./test.sh

set -uo pipefail

SPRING=http://localhost:8080
GW=http://localhost:8000

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0

pass() { echo -e "${GREEN}  ✓ $*${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}  ✗ $*${NC}"; FAIL=$((FAIL+1)); }
header() { echo -e "\n${BOLD}${YELLOW}── $* ──${NC}"; }

check() {
    # check <label> <curl args...>
    local label="$1"; shift
    local response
    response=$(curl -sf "$@" 2>&1) || { fail "$label — no response (is the service running?)"; return; }
    if echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0)" 2>/dev/null; then
        pass "$label"
        echo "$response" | python3 -m json.tool 2>/dev/null | head -20
    else
        fail "$label — unexpected response: ${response:0:120}"
    fi
    echo ""
}

echo -e "\n${BOLD}IBOR Platform — Endpoint Smoke Test${NC}"
echo "$(date)"

# ── Spring Boot ───────────────────────────────────────────────────────────────
header "Spring Boot  :8080"

check "Health" \
    "$SPRING/actuator/health"

check "Positions  (P-ALPHA, 2025-02-04)" \
    "$SPRING/api/positions?portfolioCode=P-ALPHA&asOf=2025-02-04"

check "Positions  (P-ALPHA, 2025-01-03)" \
    "$SPRING/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03"

check "Prices     (EQ-AAPL, Jan 2025)" \
    "$SPRING/api/prices/EQ-AAPL?from=2025-01-01&to=2025-01-31"

check "Drilldown  (P-ALPHA / EQ-IBM, 2025-02-04)" \
    "$SPRING/api/positions/P-ALPHA/EQ-IBM?asOf=2025-02-04"

# ── AI Gateway ────────────────────────────────────────────────────────────────
header "AI Gateway  :8000"

check "Health" \
    "$GW/health"

check "POST /analyst/positions  (P-ALPHA, 2025-02-04)" \
    -X POST "$GW/analyst/positions" \
    -H "Content-Type: application/json" \
    -d '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04"}'

check "POST /analyst/positions  (P-ALPHA, 2025-01-03)" \
    -X POST "$GW/analyst/positions" \
    -H "Content-Type: application/json" \
    -d '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03"}'

check "POST /analyst/trades     (P-ALPHA / EQ-IBM, 2025-02-04)" \
    -X POST "$GW/analyst/trades" \
    -H "Content-Type: application/json" \
    -d '{"portfolio_code":"P-ALPHA","instrument_code":"EQ-IBM","as_of":"2025-02-04"}'

check "POST /analyst/prices     (EQ-AAPL, Jan 2025)" \
    -X POST "$GW/analyst/prices" \
    -H "Content-Type: application/json" \
    -d '{"instrument_code":"EQ-AAPL","from_date":"2025-01-01","to_date":"2025-01-31"}'

check "POST /analyst/pnl        (P-ALPHA, Jan→Feb 2025)" \
    -X POST "$GW/analyst/pnl" \
    -H "Content-Type: application/json" \
    -d '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04","prior":"2025-01-03"}'

header "AI Chat  (requires OpenAI key)"

check "POST /analyst/chat — positions question" \
    -X POST "$GW/analyst/chat" \
    -H "Content-Type: application/json" \
    -d '{"question":"What are the positions in portfolio P-ALPHA as of February 4, 2025?"}'

check "POST /analyst/chat — P&L question" \
    -X POST "$GW/analyst/chat" \
    -H "Content-Type: application/json" \
    -d '{"question":"What is the P&L of P-ALPHA between January 3 and February 4, 2025?"}'

check "POST /analyst/chat — price question" \
    -X POST "$GW/analyst/chat" \
    -H "Content-Type: application/json" \
    -d '{"question":"Show me the price history for EQ-AAPL in January 2025"}'

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
TOTAL=$((PASS+FAIL))
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  All $TOTAL tests passed${NC}"
else
    echo -e "${RED}${BOLD}  $FAIL/$TOTAL tests failed${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
[[ $FAIL -eq 0 ]]
