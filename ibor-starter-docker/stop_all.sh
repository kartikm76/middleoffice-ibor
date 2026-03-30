#!/bin/bash
# Stop all Docker containers (docker-compose deployment)
# Usage: ./stop_all.sh
#
# This script:
# 1. Stops all running containers
# 2. Removes containers and networks
# 3. Preserves PostgreSQL volumes (data persists)
#
# To also delete volumes: docker-compose down --volumes

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok() { echo -e "${GREEN}✓ $*${NC}"; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
info "Stopping Docker services..."
echo ""

cd "$ROOT"

# Stop all containers (preserve volumes for data persistence)
info "Stopping containers..."
docker-compose down >/dev/null 2>&1 || true
ok "All containers stopped"

echo ""
echo -e "${GREEN}Docker services stopped${NC}"
echo ""
echo "To also delete PostgreSQL data:"
echo "  docker-compose down --volumes"
echo ""
