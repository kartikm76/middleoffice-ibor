#!/bin/bash
# Start all services in background for testing
# Usage: ./start_all.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok() { echo -e "${GREEN}✓ $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}"; exit 1; }

# ────────────────────────────────────────────────────────────────────
# Step 1: Start PostgreSQL
# ────────────────────────────────────────────────────────────────────

info "Step 1: Starting PostgreSQL..."
cd "$ROOT"
docker-compose up -d
sleep 5

# Verify PostgreSQL is ready
if docker exec docker-postgres-1 pg_isready -U ibor -d ibor >/dev/null 2>&1; then
    ok "PostgreSQL is running"
else
    error "PostgreSQL failed to start"
fi

# ────────────────────────────────────────────────────────────────────
# Step 2: Initialize database schema
# ────────────────────────────────────────────────────────────────────

info "Step 2: Initializing database schema..."
bash "$ROOT/ibor-starter/2_data_bootstrap.sh" init_infra >/dev/null 2>&1
ok "Database schema initialized"

# Verify conversation tables exist
TABLES=$(docker exec docker-postgres-1 psql -U ibor -d ibor -tAc "SELECT COUNT(*) FROM pg_tables WHERE schemaname='conv'")
if [ "$TABLES" -gt 0 ]; then
    ok "Conversation tables created ($TABLES tables)"
else
    error "Conversation tables not found"
fi

# ────────────────────────────────────────────────────────────────────
# Step 3: Start Spring Boot
# ────────────────────────────────────────────────────────────────────

info "Step 3: Starting Spring Boot..."
cd "$ROOT/ibor-middleware"

# Start in background, capture PID
mvn spring-boot:run -q > /tmp/spring-boot.log 2>&1 &
SPRING_PID=$!
echo $SPRING_PID > /tmp/spring-boot.pid

# Wait for Spring Boot to be ready (check health endpoint)
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        ok "Spring Boot is running (PID: $SPRING_PID)"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -eq $TIMEOUT ]; then
    error "Spring Boot failed to start within ${TIMEOUT}s (check /tmp/spring-boot.log)"
fi

# ────────────────────────────────────────────────────────────────────
# Step 4: Start FastAPI
# ────────────────────────────────────────────────────────────────────

info "Step 4: Starting FastAPI..."
cd "$ROOT/ibor-ai-gateway"

# Create .env if not exists
if [ ! -f .env ]; then
    cat > .env <<EOF
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-sk-ant-placeholder}
OPENAI_API_KEY=${OPENAI_API_KEY:-sk-placeholder}
PG_DSN=postgresql://ibor:ibor@localhost:5432/ibor
STRUCTURED_API_BASE=http://localhost:8080/api
EOF
    ok "Created .env file"
fi

# Start in background
uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port 8000 > /tmp/fastapi.log 2>&1 &
FASTAPI_PID=$!
echo $FASTAPI_PID > /tmp/fastapi.pid

# Wait for FastAPI to be ready
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        ok "FastAPI is running (PID: $FASTAPI_PID)"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -eq $TIMEOUT ]; then
    error "FastAPI failed to start within ${TIMEOUT}s (check /tmp/fastapi.log)"
fi

# ────────────────────────────────────────────────────────────────────
# All services started!
# ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All services started successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Service Status:"
echo "  PostgreSQL:  ✓ http://localhost:5432 (docker-postgres-1)"
echo "  Spring Boot: ✓ http://localhost:8080/health"
echo "  FastAPI:     ✓ http://localhost:8000/health"
echo ""
echo "🧪 Test Endpoint:"
echo "  Base URL: http://localhost:8000/test/conversation"
echo ""
echo "📝 Available Test Routes:"
echo "  POST /test/conversation/create-conversation   - Create/load conversation"
echo "  POST /test/conversation/save-message          - Save message to conversation"
echo "  POST /test/conversation/get-history           - Get conversation history"
echo "  POST /test/conversation/search-similar        - Search similar conversations"
echo "  GET  /test/conversation/health                - Health check"
echo ""
echo "📚 API Documentation:"
echo "  FastAPI Docs: http://localhost:8000/docs"
echo "  Spring Boot:  http://localhost:8080/swagger-ui.html"
echo ""
echo "🛑 To stop services:"
echo "  ./stop_all.sh"
echo ""
echo "📋 Service Logs:"
echo "  Spring Boot: tail -f /tmp/spring-boot.log"
echo "  FastAPI:     tail -f /tmp/fastapi.log"
echo ""
