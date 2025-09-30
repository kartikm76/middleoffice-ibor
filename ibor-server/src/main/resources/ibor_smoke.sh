#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8080}

pass() { printf "\033[32m✔ %s\033[0m\n" "$1"; }
fail() { printf "\033[31m✖ %s\033[0m\n" "$1"; exit 1; }

expect_status() {
  local method="$1"; shift
  local url="$1"; shift
  local want="$1"; shift
  local desc="$1"; shift || true
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url")
  if [[ "$code" == "$want" ]]; then
    pass "${desc:-$method $url} → $code"
  else
    fail "${desc:-$method $url} → got $code, want $want"
  fi
}

echo "== IBOR Structured API smoke tests =="
echo "BASE_URL=$BASE_URL"

# 0) Liveness
expect_status GET "$BASE_URL/actuator/health" 200 "Actuator health"

# 1) OpenAPI
expect_status GET "$BASE_URL/v3/api-docs" 200 "OpenAPI docs"

# 2) Structured/position
expect_status GET "$BASE_URL/api/structured/position?tickerOrId=IBM" 200 "Position (IBM aggregate)"
expect_status GET "$BASE_URL/api/structured/position?tickerOrId=IBM&portfolioIds=ALPHA" 200 "Position (IBM in ALPHA)"
expect_status GET "$BASE_URL/api/structured/position?tickerOrId=IBM&portfolioIds=BETA,GM" 200 "Position (IBM in BETA,GM)"
expect_status GET "$BASE_URL/api/structured/position?tickerOrId=US91282CJK11&portfolioIds=ALPHA" 200 "Position (Bond in ALPHA)"

# 3) Structured/cash-projection
expect_status GET "$BASE_URL/api/structured/cash-projection?portfolioIds=ALPHA" 200 "Cash projection (ALPHA)"
expect_status GET "$BASE_URL/api/structured/cash-projection?portfolioIds=ALPHA,BETA&days=3" 200 "Cash projection (ALPHA,BETA, days=3)"

# 4) Negative: unknown portfolio → 404
expect_status GET "$BASE_URL/api/structured/position?tickerOrId=IBM&portfolioIds=NOPE" 404 "Position with invalid portfolio → 404"

echo
echo "== Sample payloads =="
echo "-- Position IBM (ALPHA) --"
curl -s "$BASE_URL/api/structured/position?tickerOrId=IBM&portfolioIds=ALPHA" | jq . || true
echo
echo "-- Cash projection (ALPHA) --"
curl -s "$BASE_URL/api/structured/cash-projection?portfolioIds=ALPHA" | jq . || true

echo
pass "All smoke checks completed"
