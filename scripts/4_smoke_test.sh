#!/usr/bin/env bash
# 4_smoke_test.sh — Verify all endpoints return correct business data
# Requires services to be running (run 3_services_start.sh first).
#
# Usage: ./scripts/4_smoke_test.sh

set -uo pipefail
SPRING=http://localhost:8080
GW=http://localhost:8000

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0

pass() { echo -e "${GREEN}  ✓ $*${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}  ✗ $*${NC}"; FAIL=$((FAIL+1)); }
section() { echo -e "\n${BOLD}${YELLOW}── $* ──${NC}"; }

check_get() {
    local label="$1" url="$2"
    local out
    out=$(curl -sf "$url" 2>&1) || { fail "$label  →  no response"; return; }
    pass "$label"
    echo "$out" | python3 -m json.tool 2>/dev/null | head -20
    echo ""
}

check_post() {
    local label="$1" url="$2" body="$3"
    local out
    out=$(curl -sf -X POST "$url" -H "Content-Type: application/json" -d "$body" 2>&1) \
        || { fail "$label  →  no response"; return; }
    pass "$label"
    echo "$out" | python3 -m json.tool 2>/dev/null | head -25
    echo ""
}

echo -e "\n${BOLD}[4/4] Smoke Test — Business Data Verification${NC}"
echo "$(date)"

# ══════════════════════════════════════════════════════════════════════════════
section "Spring Boot  :8080"
# ══════════════════════════════════════════════════════════════════════════════

check_get \
    "Health check" \
    "$SPRING/actuator/health"

check_get \
    "Positions — P-ALPHA as of 2025-02-04  (expect: EQ-IBM short, FUT-ESZ5 long)" \
    "$SPRING/api/positions?portfolioCode=P-ALPHA&asOf=2025-02-04"

check_get \
    "Positions — P-ALPHA as of 2025-01-03  (expect: EQ-AAPL, EQ-IBM, BOND-UST10, OPT)" \
    "$SPRING/api/positions?portfolioCode=P-ALPHA&asOf=2025-01-03"

check_get \
    "Prices — EQ-AAPL Jan 2025  (expect: 1 price point at 198.12)" \
    "$SPRING/api/prices/EQ-AAPL?from=2025-01-01&to=2025-01-31"

check_get \
    "Position drilldown — P-ALPHA / EQ-IBM 2025-02-04  (expect: BUY T-0001 + adjustment)" \
    "$SPRING/api/positions/P-ALPHA/EQ-IBM?asOf=2025-02-04"

# ══════════════════════════════════════════════════════════════════════════════
section "AI Gateway  :8000  (deterministic endpoints)"
# ══════════════════════════════════════════════════════════════════════════════

check_get \
    "Health check" \
    "$GW/health"

check_post \
    "Positions — P-ALPHA 2025-02-04  (expect: totalMarketValue 258510)" \
    "$GW/analyst/positions" \
    '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04"}'

check_post \
    "Positions — P-ALPHA 2025-01-03  (expect: 5 positions)" \
    "$GW/analyst/positions" \
    '{"portfolio_code":"P-ALPHA","as_of":"2025-01-03"}'

check_post \
    "Trades — P-ALPHA / EQ-IBM 2025-02-04  (expect: BUY 100 @ 170 + ADJUST -10)" \
    "$GW/analyst/trades" \
    '{"portfolio_code":"P-ALPHA","instrument_code":"EQ-IBM","as_of":"2025-02-04"}'

check_post \
    "Prices — EQ-AAPL Jan 2025  (expect: min/max/last 198.12)" \
    "$GW/analyst/prices" \
    '{"instrument_code":"EQ-AAPL","from_date":"2025-01-01","to_date":"2025-01-31"}'

check_post \
    "P&L — P-ALPHA Jan→Feb 2025  (expect: delta 231079, prev 27431, curr 258510)" \
    "$GW/analyst/pnl" \
    '{"portfolio_code":"P-ALPHA","as_of":"2025-02-04","prior":"2025-01-03"}'

# ══════════════════════════════════════════════════════════════════════════════
section "AI Gateway  :8000  (chat — requires OpenAI key)"
# ══════════════════════════════════════════════════════════════════════════════

check_post \
    "Chat: positions question" \
    "$GW/analyst/chat" \
    '{"question":"What are the positions in portfolio P-ALPHA as of February 4, 2025?"}'

check_post \
    "Chat: P&L question" \
    "$GW/analyst/chat" \
    '{"question":"What is the P&L of P-ALPHA between January 3 and February 4, 2025?"}'

check_post \
    "Chat: price history question" \
    "$GW/analyst/chat" \
    '{"question":"Show me the price history for EQ-AAPL in January 2025"}'

# ══════════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS+FAIL))
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  All $TOTAL tests passed${NC}"
else
    echo -e "${RED}${BOLD}  $FAIL/$TOTAL tests FAILED${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
[[ $FAIL -eq 0 ]]
