#!/usr/bin/env bash
# Apply ALL SQL files from ./docker/init into the running DB (in filename order).
# Useful when you modify files there and want to re-run without nuking volumes.
#
# NOTE: Postgres' entrypoint runs these only on first init; this script lets you reapply.

set -euo pipefail

INIT_DIR=${INIT_DIR:-./docker/init}
CONTAINER=${CONTAINER:-ibor_db}
DB=${DB:-ibordb}
USER=${USER:-ibor_user}

if [[ ! -d "$INIT_DIR" ]]; then
  echo "❌ INIT_DIR not found: $INIT_DIR"
  exit 1
fi

shopt -s nullglob
files=( "$INIT_DIR"/*.sql )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "⚠️  No .sql files found in $INIT_DIR"
  exit 0
fi

echo "Found ${#files[@]} SQL files in $INIT_DIR:"
for f in "${files[@]}"; do echo " - $(basename "$f")"; done

for f in "${files[@]}"; do
  base=$(basename "$f")
  echo ">> Applying $base"
  docker cp "$f" "${CONTAINER}:/tmp/${base}"
  docker exec -i "${CONTAINER}" psql -U "${USER}" -d "${DB}" -f "/tmp/${base}"
done

echo "✅ ./docker/init SQLs re-applied."
