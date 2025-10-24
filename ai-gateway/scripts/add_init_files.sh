#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"

echo "Scanning for Python packages under: ${SRC_DIR}"

# find all dirs that contain at least one .py (excluding __pycache__)
mapfile -t dirs < <(find "${SRC_DIR}" -type d ! -name "__pycache__")

created=0
for d in "${dirs[@]}"; do
  # has python code inside this dir or subdir?
  if find "$d" -maxdepth 1 -type f -name "*.py" | grep -q . || \
     find "$d" -mindepth 1 -type d ! -name "__pycache__" | grep -q .; then
    if [[ ! -f "$d/__init__.py" ]]; then
      : > "$d/__init__.py"
      ((created++))
      echo "  + $d/__init__.py"
    fi
  fi
done

echo "Done. Created ${created} __init__.py files."