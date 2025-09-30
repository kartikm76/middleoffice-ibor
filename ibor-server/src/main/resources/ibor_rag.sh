#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8080}
JSON='Content-Type: application/json'

run() {
  local name="$1"
  local data="$2"
  printf "\n== %s ==\n" "$name"
  curl -s -X POST "$BASE_URL/api/rag/hybrid" -H "$JSON" -d "$data" | jq . || true
}

echo "🔍 Testing RAG Hybrid API at $BASE_URL"

# ✅ Happy path (IBM + ALPHA)
run "RAG hybrid: IBM + ALPHA" '{
  "question":"What changed in IBM notes last week?",
  "instrumentTicker":"IBM",
  "portfolioCodes":["ALPHA"],
  "topK":5
}'

# ✅ IBM across ALPHA & BETA
run "RAG hybrid: IBM ALPHA,BETA" '{
  "question":"Summarize recent IBM notes across portfolios.",
  "instrumentTicker":"IBM",
  "portfolioCodes":["ALPHA","BETA"],
  "topK":8
}'

# ✅ No portfolio filter (all)
run "RAG hybrid: IBM (no portfolio filter)" '{
  "question":"Any commentary on IBM risk drivers?",
  "instrumentTicker":"IBM",
  "topK":5
}'

# ✅ AAPL
run "RAG hybrid: AAPL" '{
  "question":"What changed in AAPL notes this month?",
  "instrumentTicker":"AAPL",
  "portfolioCodes":["ALPHA"],
  "topK":5
}'

# ⚠️ Negative: unknown ticker
printf "\n== Negative (unknown ticker) ==\n"
curl -i -s -X POST "$BASE_URL/api/rag/hybrid" \
  -H "$JSON" \
  -d '{
    "question":"Test unknown ticker handling",
    "instrumentTicker":"NO_SUCH_TICKER",
    "portfolioCodes":["ALPHA"],
    "topK":3
  }' | head -n 20

# ⚠️ Negative: unknown portfolio
printf "\n== Negative (unknown portfolio) ==\n"
curl -i -s -X POST "$BASE_URL/api/rag/hybrid" \
  -H "$JSON" \
  -d '{
    "question":"Test unknown portfolio handling",
    "instrumentTicker":"IBM",
    "portfolioCodes":["NOPE"],
    "topK":3
  }' | head -n 20

echo -e "\n✅ All RAG hybrid smoke tests executed."