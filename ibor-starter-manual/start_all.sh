#!/bin/bash
# Start all services in background for local development testing
# Usage: ./start_all.sh
#
# This script:
# 1. Starts PostgreSQL in Docker
# 2. Initializes database schema
# 3. Loads CSV data into staging tables
# 4. Starts Spring Boot
# 5. Starts Python FastAPI gateway
# 6. Starts React UI (optional, usually run separately)
#
# Logs are written to .spring-boot.log, .gateway.log, .ui.log

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

info "Step 1/5: Starting PostgreSQL..."
cd "$ROOT"
docker-compose up -d postgres bootstrap >/dev/null 2>&1
sleep 3

# Wait for bootstrap to complete
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker ps | grep -q "ibor-bootstrap"; then
        # Bootstrap container is still running, wait
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    else
        # Bootstrap exited (successful or failed)
        BOOTSTRAP_LOGS=$(docker logs ibor-bootstrap 2>&1)
        if echo "$BOOTSTRAP_LOGS" | grep -q "✓ Data loaded successfully"; then
            ok "Database initialized and data loaded"
            break
        else
            # Check if it's because data already exists
            if docker exec ibor-postgres psql -U ibor -d ibor -tAc "SELECT COUNT(*) FROM ibor.fact_position_snapshot" 2>/dev/null | grep -q "[0-9]"; then
                ok "Database already has data"
                break
            fi
        fi
    fi
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    error "Database initialization timed out (check: docker logs ibor-bootstrap)"
fi

# ────────────────────────────────────────────────────────────────────
# Step 2: Start Spring Boot
# ────────────────────────────────────────────────────────────────────

info "Step 2/5: Starting Spring Boot..."
cd "$ROOT/ibor-middleware"

# Set Java 21
export JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null || echo "")
if [ -z "$JAVA_HOME" ]; then
    error "Java 21 not found. Install with: brew install openjdk@21"
fi

# Start in background
mvn spring-boot:run -q > "$ROOT/.spring-boot.log" 2>&1 &
SPRING_PID=$!
echo $SPRING_PID > /tmp/spring-boot.pid

# Wait for Spring Boot to be ready
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
        ok "Spring Boot is running (PID: $SPRING_PID)"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -eq $TIMEOUT ]; then
    error "Spring Boot failed to start within ${TIMEOUT}s (check .spring-boot.log)"
fi

# ────────────────────────────────────────────────────────────────────
# Step 3: Start Python FastAPI Gateway
# ────────────────────────────────────────────────────────────────────

info "Step 3/5: Starting Python FastAPI Gateway..."
cd "$ROOT/ibor-ai-gateway"

# Check dependencies
if ! python3 -c "import fastapi" 2>/dev/null; then
    error "Python dependencies not installed. Run: uv sync"
fi

# Start in background
uv run uvicorn ai_gateway.main:app --host 127.0.0.1 --port 8000 > "$ROOT/.gateway.log" 2>&1 &
GATEWAY_PID=$!
echo $GATEWAY_PID > /tmp/gateway.pid

# Wait for FastAPI to be ready
TIMEOUT=30
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        ok "FastAPI is running (PID: $GATEWAY_PID)"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -eq $TIMEOUT ]; then
    error "FastAPI failed to start within ${TIMEOUT}s (check .gateway.log)"
fi

# ────────────────────────────────────────────────────────────────────
# Step 4: Start React UI (optional)
# ────────────────────────────────────────────────────────────────────

info "Step 4/5: Starting React UI..."
cd "$ROOT/ibor-ui"

# Check if npm install is needed
if [ ! -d node_modules ]; then
    info "Installing npm dependencies..."
    npm install >/dev/null 2>&1 || error "npm install failed"
fi

# Start in background
npm run dev > "$ROOT/.ui.log" 2>&1 &
UI_PID=$!
echo $UI_PID > /tmp/ui.pid

# Wait for React to be ready
TIMEOUT=30
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -s http://localhost:5173 >/dev/null 2>&1; then
        ok "React UI is running (PID: $UI_PID)"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -eq $TIMEOUT ]; then
    # React dev server might be ready even if curl fails
    ok "React UI started (check .ui.log)"
fi

# ────────────────────────────────────────────────────────────────────
# Done
# ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}All services started!${NC}"
echo ""
echo "  Spring Boot:   http://localhost:8080/swagger-ui.html"
echo "  FastAPI:       http://localhost:8000/docs"
echo "  React UI:      http://localhost:5173"
echo ""
echo "Logs:"
echo "  .spring-boot.log  — Spring Boot logs"
echo "  .gateway.log      — FastAPI logs"
echo "  .ui.log           — React logs"
echo ""
echo "To stop all services: bash ibor-starter-manual/stop_all.sh"
echo ""
