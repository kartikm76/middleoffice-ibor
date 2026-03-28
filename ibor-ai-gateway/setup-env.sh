#!/bin/bash
# Frozen environment setup for ibor-ai-gateway
# Recreates Python venv from uv.lock to ensure reproducible dependencies

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${YELLOW}==> $*${NC}"; }
ok() { echo -e "${GREEN}✓ $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}"; exit 1; }

info "Setting up frozen Python environment from uv.lock..."
echo ""

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    error "uv not found. Install with: brew install uv"
fi

# Remove old venv if exists
if [ -d .venv ]; then
    info "Removing old virtual environment..."
    rm -rf .venv
fi

# Sync from uv.lock (deterministic, frozen dependencies)
info "Creating virtual environment from uv.lock..."
uv sync --frozen

ok "Python environment setup complete"
echo ""
echo "Environment details:"
.venv/bin/python --version
echo ""
echo "Verifying core dependencies..."
.venv/bin/python -c "import anthropic, openai, fastapi, uvicorn, psycopg, pydantic; print('✓ All core dependencies available')" || error "Missing dependencies"
echo ""
ok "Environment is frozen and reproducible"
echo ""
echo "Next steps:"
echo "  1. Set environment variables in .env (if needed)"
echo "  2. Run: ./start_all.sh"
echo ""
