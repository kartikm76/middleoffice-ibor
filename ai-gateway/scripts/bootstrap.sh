#!/usr/bin/env bash
set -e

# Resolve project root (parent of scripts/)
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
cd "$PROJECT_ROOT"

echo "🔧 BOOTSTRAP STARTED"
echo "📍 Project directory: $PROJECT_ROOT"
echo

# Step 1 - Ensure __init__.py in necessary directories
echo "📦 Ensuring package structure..."
uv run python scripts/ensure_packages.py --src src --fix
echo

# Step 2 - Clean old __pycache__
echo "🧹 Cleaning stale __pycache__ folders..."
bash scripts/clean_pycache.sh
echo

# Step 3 - Launch API Gateway (FastAPI)
echo "🚀 Starting AI Gateway service..."
echo "👉 Visit http://localhost:8000/docs for API Swagger UI"
uv run python -m ai_gateway.app