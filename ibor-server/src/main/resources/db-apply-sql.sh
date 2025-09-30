#!/usr/bin/env bash
# Apply one or more SQL files into the running DB container.
# Paths can be anywhere (e.g., ./docker/init/01_schema.sql or ./patches/add_index.sql).

set -euo pipefail

CONTAINER=${CONTAINER:-ibor_db}
DB=${DB:-ibordb}
USER=${USER:-ibor_user}

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sql-file> [sql-file2 ...]"
  echo "Environment: CONTAINER=ibor_db DB=ibordb USER=ibor_user"
  exit 1
fi

for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ File not found: $f"
    exit 1
  fi
done

for f in "$@"; do
  base=$(basename "$f")
  echo ">> Applying $f"
  docker cp "$f" "${CONTAINER}:/tmp/${base}"
  docker exec -i "${CONTAINER}" psql -U "${USER}" -d "${DB}" -f "/tmp/${base}"
done

echo "✅ All scripts applied."
