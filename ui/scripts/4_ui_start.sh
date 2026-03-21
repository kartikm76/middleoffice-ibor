#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "\n${YELLOW}[4/4] UI Dev Server${NC}\n"
cd "$ROOT/ui"
if [[ ! -d node_modules ]]; then
  echo "Installing dependencies..."
  npm install
fi
echo -e "${GREEN}  Starting Vite dev server at http://localhost:5173${NC}"
npm run dev
