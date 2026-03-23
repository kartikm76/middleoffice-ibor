#!/usr/bin/env bash
# data_etl.sh — Full ETL pipeline: schema init + CSV staging + curated load
#
# Usage:
#   ./scripts/data_etl.sh <init_infra|load_staging|load_main|full>
#
# Env overrides:
#   DB_NAME, DB_USER, USE_COMPOSE, SERVICE, CONTAINER, INIT_DIR, DATA_DIR, MAPPING_JSON
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# -----------------------------
# Defaults (override via env)
# -----------------------------
DB_NAME="${DB_NAME:-ibor}"
DB_USER="${DB_USER:-ibor}"
USE_COMPOSE="${USE_COMPOSE:-true}"      # true|false
SERVICE="${SERVICE:-postgres}"          # docker-compose service name
CONTAINER="${CONTAINER:-}"              # if blank, we'll auto-detect
INIT_DIR="${INIT_DIR:-$ROOT/ibor-db/init}"  # host path to SQL init scripts
DATA_DIR="${DATA_DIR:-$ROOT/ibor-db/data}"  # host path to CSVs
MAPPING_JSON="${MAPPING_JSON:-$DATA_DIR/stg_mapping.json}"
PGHOST_OVERRIDE="${PGHOST_OVERRIDE:-}"

# -----------------------------
# Helpers
# -----------------------------
die()  { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
say()  { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

need docker
need jq

resolve_container() {
  if [[ -n "$CONTAINER" ]]; then
    echo "$CONTAINER"; return
  fi

  if [[ "${USE_COMPOSE}" == "true" ]]; then
    local cid
    if cid="$(docker compose -f "$ROOT/docker-compose.yml" ps -q "$SERVICE" 2>/dev/null)"; then
      if [[ -n "$cid" ]]; then
        docker inspect --format '{{.Name}}' "$cid" | sed 's#^/##'
        return
      fi
    fi
    warn "compose service '$SERVICE' not running; will try a running pgvector container"
  fi

  local cname
  cname="$(docker ps --filter "ancestor=pgvector/pgvector:pg16" --format "{{.Names}}" | head -n1)"
  [[ -n "$cname" ]] || die "No running container found for pgvector/pgvector:pg16. Start infra first."
  echo "$cname"
}

CONTAINER="$(resolve_container)"

say "Using container=${CONTAINER} db=${DB_NAME} user=${DB_USER}"
say "Host init_dir=${INIT_DIR}  (piped to psql)"
say "Host data_dir=${DATA_DIR}"
say "Mapping JSON: ${MAPPING_JSON}"

_psql() {
  local sql="$1"
  local env_flag=()
  [[ -n "${PGHOST_OVERRIDE}" ]] && env_flag=( "-e" "PGHOST=${PGHOST_OVERRIDE}" )
  docker exec "${env_flag[@]}" -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$sql"
}

apply_sql() {
  local host_file="$1"
  [[ -f "$host_file" ]] || die "SQL file not found: $host_file"
  say "Applying: $host_file"
  docker exec -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -f - < "$host_file"
}

db_ready() {
  docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null 2>&1
}

wait_for_db() {
  say "Health check (psql)"
  local tries=30 i=1
  until db_ready; do
    [[ $i -ge $tries ]] && die "Database did not become ready in time."
    sleep 1; i=$((i+1))
  done
}

copy_csv_stdin() {
  local table="$1" cols="$2" csv_path="$3"
  [[ -f "$csv_path" ]] || { warn "Missing CSV: $csv_path"; return 0; }
  say "  -> ${table} <= $(basename "$csv_path")"
  local stmt="\COPY ${table} (${cols}) FROM STDIN CSV HEADER NULL ''"
  docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c "$stmt" < "$csv_path"
}

# ── Phases ────────────────────────────────────────────────────────────────────

init_infra() {
  wait_for_db
  apply_sql "$INIT_DIR/01_main_schema.sql"
  apply_sql "$INIT_DIR/02_staging_schema.sql"
  apply_sql "$INIT_DIR/03_audit_trigger.sql"
  apply_sql "$INIT_DIR/04_loaders.sql"
  apply_sql "$INIT_DIR/05_helpers.sql"
  apply_sql "$INIT_DIR/06_vw_instrument.sql"
  apply_sql "$INIT_DIR/07_dim_instrument_partitioning.sql"
  apply_sql "$INIT_DIR/08_analytics_schema.sql"
  say "Schemas & functions applied."
}

load_staging() {
  [[ -f "$MAPPING_JSON" ]] || die "Mapping JSON not found: $MAPPING_JSON"
  say "Copying CSVs into staging (via STDIN; portable)"
  wait_for_db

  jq -e '.staging and ( .staging | type=="object" )' "$MAPPING_JSON" >/dev/null \
    || die "Invalid mapping JSON structure"

  while IFS=$'\t' read -r csv table cols; do
    [[ -z "$csv" || -z "$table" || -z "$cols" ]] && continue
    copy_csv_stdin "$table" "$cols" "$DATA_DIR/$csv"
  done < <(
    jq -r '
      .staging
      | to_entries[]
      | [.key, .value.table, (.value.columns | join(","))]
      | @tsv
    ' "$MAPPING_JSON"
  )

  say "Staging load complete."
}

load_main() {
  wait_for_db
  _psql "SELECT ibor.run_all_loaders();"
  say "Curated (dims/facts) load complete."
}

usage() {
  cat <<EOF
Usage: $0 <init_infra|load_staging|load_main|full>

  init_infra   - Apply SQL init scripts (DROP/CREATE schemas + functions)
  load_staging - COPY all CSVs into stg.* tables using stg_mapping.json
  load_main    - Promote stg.* → ibor.* (calls ibor.run_all_loaders())
  full         - init_infra + load_staging + load_main

Env overrides:
  DB_NAME, DB_USER, USE_COMPOSE, SERVICE, CONTAINER, INIT_DIR, DATA_DIR, MAPPING_JSON
EOF
}

# -----------------------------
# Main
# -----------------------------
MODE="${1:-}"
[[ -z "$MODE" ]] && { usage; exit 1; }

case "$MODE" in
  init_infra)   init_infra ;;
  load_staging) load_staging ;;
  load_main)    load_main ;;
  full)         init_infra; load_staging; load_main ;;
  *) usage; exit 1 ;;
esac
