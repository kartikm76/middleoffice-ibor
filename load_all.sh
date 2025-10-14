#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Defaults (override via env)
# -----------------------------
DB_NAME="${DB_NAME:-ibor}"
DB_USER="${DB_USER:-ibor}"
USE_COMPOSE="${USE_COMPOSE:-true}"      # true|false
SERVICE="${SERVICE:-postgres}"          # docker-compose service name
CONTAINER="${CONTAINER:-}"              # if blank, we’ll auto-detect
INIT_DIR="${INIT_DIR:-docker/db/init}"  # host path to SQLs
DATA_DIR="${DATA_DIR:-docker/db/data}"  # host path to CSVs
MAPPING_JSON="${MAPPING_JSON:-$DATA_DIR/stg_mapping.json}" # CSV→staging mapping
PGHOST_OVERRIDE="${PGHOST_OVERRIDE:-}"  # leave empty unless you want to force a host

# -----------------------------
# Helpers
# -----------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
say() { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

need docker
need jq

# Resolve container id/name we’ll exec into
resolve_container() {
  if [[ -n "$CONTAINER" ]]; then
    echo "$CONTAINER"
    return
  fi

  if [[ "${USE_COMPOSE}" == "true" ]]; then
    # Try compose service first
    local cid
    if cid="$(docker compose ps -q "$SERVICE" 2>/dev/null)"; then
      if [[ -n "$cid" ]]; then
        docker inspect --format '{{.Name}}' "$cid" | sed 's#^/##'
        return
      fi
    fi
    warn "compose service '$SERVICE' not running; will try a running pgvector container"
  fi

  # Fallback: look for any running container based on the pgvector image
  local cname
  cname="$(docker ps --filter "ancestor=pgvector/pgvector:pg16" --format "{{.Names}}" | head -n1)"
  [[ -n "$cname" ]] || die "No running container found for image pgvector/pgvector:pg16. Start docker-compose first."
  echo "$cname"
}

CONTAINER="$(resolve_container)"

say "Using container=${CONTAINER} db=${DB_NAME} user=${DB_USER}"
say "Host init_dir=$(cd "$INIT_DIR" && pwd)  (piped to psql)"
say "Host data_dir=$(cd "$DATA_DIR" && pwd)"
say "Mapping JSON: ${MAPPING_JSON}"

# Compose -c string to run psql inside the container
_psql() {
  local sql="$1"
  # optional PGHOST override (helpful if you use a TCP port mapping into container)
  local env_flag=()
  [[ -n "${PGHOST_OVERRIDE}" ]] && env_flag=( "-e" "PGHOST=${PGHOST_OVERRIDE}" )
  docker exec "${env_flag[@]}" -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$sql"
}

# Apply a host SQL file by piping its contents to psql (-f -)
apply_sql() {
  local host_file="$1"
  [[ -f "$host_file" ]] || die "SQL file not found: $host_file"
  say "Applying: $host_file"
  docker exec -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -f - < "$host_file"
}

# Health check: does psql respond?
db_ready() {
  if docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

wait_for_db() {
  say "Health check (psql)"
  local tries=30
  local i=1
  until db_ready; do
    [[ $i -ge $tries ]] && die "Database did not become ready in time."
    sleep 1
    i=$((i+1))
  done
}

# COPY helper: use STDIN so we never rely on container filesystem permissions
copy_csv_stdin() {
  local table="$1"   # e.g. stg.currency
  local cols="$2"    # comma list: col1,col2,...
  local csv_path="$3"
  [[ -f "$csv_path" ]] || { warn "Missing CSV: $csv_path"; return 0; }

  say "  -> ${table} <= $(basename "$csv_path")"
  # Use \COPY with STDIN inside a -c … block
  # We must single-quote the \COPY statement
  local stmt="\COPY ${table} (${cols}) FROM STDIN CSV HEADER NULL ''"
  docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c "$stmt" < "$csv_path"
}

# Load staging from mapping JSON
load_staging() {
  [[ -f "$MAPPING_JSON" ]] || die "Mapping JSON not found: $MAPPING_JSON"
  say "Copying CSVs into staging (via STDIN; portable)"
  wait_for_db

  # Validate and stream entries
  jq -e '.staging and ( .staging | type=="object" ) ' "$MAPPING_JSON" >/dev/null \
    || die "Invalid mapping JSON structure"

  # Iterate: filename, table, columns
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

# Init infra: DROP/CREATE schemas & functions
init_infra() {
  wait_for_db
  apply_sql "$INIT_DIR/01_main_schema.sql"
  apply_sql "$INIT_DIR/02_staging_schema.sql"
  apply_sql "$INIT_DIR/03_audit_trigger.sql"
  apply_sql "$INIT_DIR/04_loaders.sql"
  apply_sql "$INIT_DIR/05_helpers.sql"
  say "Schemas & functions applied."
}

# Load curated (dims/facts) from staging
load_main() {
  wait_for_db
  # Single entrypoint function runs all upserts/appends
  _psql "SELECT ibor.run_all_loaders();"
  say "Curated (dims/facts) load complete."
}

usage() {
  cat <<EOF
Usage: $0 <init_infra|load_staging|load_main|full>

  init_infra   - Apply 01..05 SQL files (DROP/CREATE schemas + helpers)
  load_staging - COPY CSVs -> staging using mapping JSON
  load_main    - Move staging -> curated (calls ibor.run_all_loaders())
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