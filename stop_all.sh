#!/bin/bash
# Stop all services

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok() { echo -e "${GREEN}✓ $*${NC}"; }

info "Stopping FastAPI..."
if [ -f /tmp/fastapi.pid ]; then
    kill $(cat /tmp/fastapi.pid) 2>/dev/null || true
    rm /tmp/fastapi.pid
    ok "FastAPI stopped"
else
    echo "  (not running)"
fi

info "Stopping Spring Boot..."
if [ -f /tmp/spring-boot.pid ]; then
    kill $(cat /tmp/spring-boot.pid) 2>/dev/null || true
    rm /tmp/spring-boot.pid
    ok "Spring Boot stopped"
else
    echo "  (not running)"
fi

info "Stopping PostgreSQL..."
docker-compose down >/dev/null 2>&1 || true
ok "PostgreSQL stopped"

echo ""
echo -e "${GREEN}All services stopped${NC}"
