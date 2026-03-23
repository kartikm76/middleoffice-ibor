#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Cleaning __pycache__ and *.py[cod] under: ${ROOT_DIR}"
find "${ROOT_DIR}" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "${ROOT_DIR}" -type f \( -name "*.pyc" -o -name "*.pyo" -o -name "*.pyd" \) -delete
echo "Clean complete."