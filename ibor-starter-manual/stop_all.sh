#!/bin/bash
# Stop all local services (manual development environment)
# Usage: ./stop_all.sh
#
# This script terminates:
# 1. React UI (npm dev process)
# 2. FastAPI gateway (uvicorn process)
# 3. Spring Boot (Maven process)
# 4. PostgreSQL (Docker container)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok() { echo -e "${GREEN}✓ $*${NC}"; }

echo ""
info "Stopping local services..."
echo ""

# Stop React UI
info "Stopping React UI..."
if [ -f /tmp/ui.pid ]; then
    kill $(cat /tmp/ui.pid) 2>/dev/null || true
    rm /tmp/ui.pid
    ok "React UI stopped"
else
    echo "  (not running)"
fi

# Stop FastAPI Gateway
info "Stopping FastAPI Gateway..."
if [ -f /tmp/gateway.pid ]; then
    kill $(cat /tmp/gateway.pid) 2>/dev/null || true
    rm /tmp/gateway.pid
    ok "FastAPI Gateway stopped"
else
    echo "  (not running)"
fi

# Stop Spring Boot
info "Stopping Spring Boot..."
if [ -f /tmp/spring-boot.pid ]; then
    kill $(cat /tmp/spring-boot.pid) 2>/dev/null || true
    rm /tmp/spring-boot.pid
    ok "Spring Boot stopped"
else
    echo "  (not running)"
fi

# Stop PostgreSQL (Docker)
info "Stopping PostgreSQL (Docker)..."
docker-compose down >/dev/null 2>&1 || true
ok "PostgreSQL stopped"

echo ""
echo -e "${GREEN}All services stopped${NC}"
echo ""
