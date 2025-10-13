#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
CONTAINER="${CONTAINER:-docker-postgres-1}"
DB="ibor"
USER="ibor"
INIT_DIR="$(pwd)/docker/db/init"
DATA_DIR="$(pwd)/docker/db/data"

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <init_infra|load_staging|load_main|full>"
  exit 1
fi

say() { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Missing '$1'"; }
need docker

# Basic liveness check
check_psql() {
  docker exec "$CONTAINER" sh -lc "psql -U $USER -d $DB -c 'SELECT 1'" >/dev/null 2>&1
}

# Run a local SQL file inside the container with psql
psql_file() {
  local file="$1"
  [[ -f "$file" ]] || die "SQL not found: $file"
  say "psql < $(basename "$file")"
  docker exec -i "$CONTAINER" sh -lc "psql -v ON_ERROR_STOP=1 -U $USER -d $DB" < "$file"
}

# COPY a CSV into a staging table via STDIN (portable; no container mounts needed)
copy_csv() {
  local table="$1"; shift
  local cols="$1"; shift
  local csv="$1"

  [[ -f "$csv" ]] || { warn "Missing $csv (skipping $table)"; return 0; }
  say "  -> $table <= $(basename "$csv")"
  docker exec -i "$CONTAINER" sh -lc "psql -v ON_ERROR_STOP=1 -U $USER -d $DB -c \"COPY $table ($cols) FROM STDIN WITH CSV HEADER NULL ''\" " < "$csv"
}

# Column lists (match 02_staging_schema.sql exactly)
declare -A STG_COLS

# reference
STG_COLS["stg.currency"]="currency_code,currency_name,minor_unit,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.exchange"]="exchange_code,exchange_name,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.price_source"]="price_source_code,price_source_name,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.strategy"]="strategy_code,strategy_name,strategy_category,source_system,source_ref,ingest_batch_id"

# SCD2 dims
STG_COLS["stg.portfolio"]="portfolio_code,portfolio_name,region,entitlement_group,valid_from,valid_to,status,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.account"]="account_code,account_name,region,entitlement_group,valid_from,valid_to,status,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.account_portfolio"]="account_code,portfolio_code,valid_from,valid_to,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.instrument"]="instrument_code,instrument_type,instrument_name,exchange_code,currency_code,status,valid_from,valid_to,source_system,source_ref,ingest_batch_id"

# subtypes
STG_COLS["stg.instrument_equity"]="instrument_code,ticker,cusip,isin,sedol,exchange_country,sector,industry_group,shares_outstanding,dividend_yield,dividend_currency,dividend_frequency,fiscal_year_end,listing_date,delisting_date,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.instrument_bond"]="instrument_code,isin,cusip,issuer_name,coupon_rate,coupon_type,coupon_frequency,day_count_convention,maturity_date,issue_date,dated_date,first_coupon_date,last_coupon_date,face_value,currency_code,country_of_issue,call_type,call_price,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.instrument_futures"]="instrument_code,contract_code,underlying_symbol,contract_size,tick_size,tick_value,quote_currency,delivery_month,expiry_date,first_notice_date,last_trading_date,settlement_type,exchange_code,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.instrument_options"]="instrument_code,option_symbol,underlying_symbol,option_type,strike_price,expiry_date,multiplier,premium_currency,exercise_style,settlement_type,exchange_code,source_system,source_ref,ingest_batch_id"

# facts staging
STG_COLS["stg.price"]="instrument_code,price_source_code,price_ts,price_type,price,currency_code,is_eod_flag,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.fx_rate"]="currency_code,rate_date,rate,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.trade_fill"]="execution_id,trade_code,account_code,instrument_code,trade_date,quantity,price,gross_amount,net_amount,broker_code,counterparty_code,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.position_snapshot"]="portfolio_code,instrument_code,position_date,quantity,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.cash_event"]="portfolio_code,event_date,amount,currency_code,event_type,notes,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.position_adjustment"]="portfolio_code,instrument_code,effective_date,quantity_delta,reason,source_system,source_ref,ingest_batch_id"

# optional references you have CSVs for
STG_COLS["stg.broker"]="broker_code,broker_name,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.counterparty"]="counterparty_code,counterparty_name,country,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.calendar"]="cal_date,is_business_day,market,source_system,source_ref,ingest_batch_id"
STG_COLS["stg.corporate_action_applied"]="instrument_code,action_code,ex_date,record_date,pay_date,factor,amount,currency_code,notes,source_system,source_ref,ingest_batch_id"
# (You also listed stg_corporate_action.csv; create its staging table/loader later if you want the raw feed too.)

# Expected CSVs (basename -> table)
declare -A CSV_MAP=(
  ["stg_currency.csv"]="stg.currency"
  ["stg_exchange.csv"]="stg.exchange"
  ["stg_price_source.csv"]="stg.price_source"
  ["stg_strategy.csv"]="stg.strategy"

  ["stg_portfolio.csv"]="stg.portfolio"
  ["stg_account.csv"]="stg.account"
  ["stg_account_portfolio.csv"]="stg.account_portfolio"
  ["stg_instrument.csv"]="stg.instrument"

  ["stg_instrument_equity.csv"]="stg.instrument_equity"
  ["stg_instrument_bond.csv"]="stg.instrument_bond"
  ["stg_instrument_futures.csv"]="stg.instrument_futures"
  ["stg_instrument_options.csv"]="stg.instrument_options"

  ["stg_price.csv"]="stg.price"
  ["stg_fx_rate.csv"]="stg.fx_rate"
  ["stg_trade_fill.csv"]="stg.trade_fill"
  ["stg_position_snapshot.csv"]="stg.position_snapshot"
  ["stg_cash_event.csv"]="stg.cash_event"
  ["stg_position_adjustment.csv"]="stg.position_adjustment"

  ["stg_broker.csv"]="stg.broker"
  ["stg_counterparty.csv"]="stg.counterparty"
  ["stg_calendar.csv"]="stg.calendar"
  ["stg_corporate_action_applied.csv"]="stg.corporate_action_applied"
)

init_infra() {
  say "Using container=$CONTAINER db=$DB user=$USER"
  say "Host init_dir=$INIT_DIR"
  say "Host data_dir=$DATA_DIR"
  say "Applying schemas & functions (DROP/CREATE ibor & stg)"
  check_psql || die "psql not reachable in container '$CONTAINER'"

  psql_file "$INIT_DIR/01_main_schema.sql"
  psql_file "$INIT_DIR/02_staging_schema.sql"
  psql_file "$INIT_DIR/03_audit_trigger.sql"
  psql_file "$INIT_DIR/05_helpers.sql"
  say "init_infra complete"
}

load_staging() {
  say "Using container=$CONTAINER db=$DB user=$USER"
  say "Copying CSVs into staging (via STDIN; portable)"
  check_psql || die "psql not reachable in container '$CONTAINER'"

  for csv in "${!CSV_MAP[@]}"; do
    table="${CSV_MAP[$csv]}"
    cols="${STG_COLS[$table]}"
    [[ -z "${cols:-}" ]] && { warn "No column list for $table (skipping)"; continue; }
    copy_csv "$table" "$cols" "$DATA_DIR/$csv"
  done
  say "staging load complete"
}

load_main() {
  say "Running loaders (dims -> facts)"
  check_psql || die "psql not reachable in container '$CONTAINER'"

  # Ensure loader functions exist
  psql_file "$INIT_DIR/04_loaders.sql"

  docker exec -i "$CONTAINER" sh -lc "psql -v ON_ERROR_STOP=1 -U $USER -d $DB -c 'SELECT ibor.run_all_loaders();'"
  say "main load complete"
}

case "$MODE" in
  init_infra)    init_infra ;;
  load_staging)  load_staging ;;
  load_main)     load_main ;;
  full)          init_infra; load_staging; load_main ;;
  *) die "Unknown mode: $MODE" ;;
esac
