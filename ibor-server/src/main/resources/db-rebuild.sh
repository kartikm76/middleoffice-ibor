#!/usr/bin/env bash
# Rebuild ONLY the DB service using your compose setup.
# Project structure assumed:
#   docker/
#     db/    -> Dockerfile for Postgres image
#     init/  -> *.sql run at first init via /docker-entrypoint-initdb.d
#
# Service name: db
# Container: ibor_db
# DB: ibordb, User: ibor_user

set -euo pipefail

SERVICE=${SERVICE:-db}
CONTAINER=${CONTAINER:-ibor_db}

echo "This will STOP the '${SERVICE}' service, DELETE the data volume, and RECREATE the database container."
echo "Your init SQLs will run from ./docker/init on FIRST initialization only."
read -r -p "Are you sure? This will ERASE all data. Type 'YES' to continue: " CONFIRM
if [[ "${CONFIRM:-}" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

echo ">> Bringing stack down and removing volumes..."
docker compose down -v

echo ">> Building and starting '${SERVICE}'..."
docker compose up -d --build "${SERVICE}"

echo ">> Waiting for container health..."
for i in {1..30}; do
  status=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER}" 2>/dev/null || echo "unknown")
  echo "  - Health: ${status}"
  if [[ "$status" == "healthy" ]]; then
    echo "✅ ${CONTAINER} is healthy."
    echo "ℹ️  If you add/change SQL in ./docker/init later, use db-apply-init.sh or db-apply-sql.sh to apply without rebuild."
    exit 0
  fi
  sleep 2
done

echo "⚠️  Timed out waiting for ${CONTAINER} to become healthy."
exit 1
