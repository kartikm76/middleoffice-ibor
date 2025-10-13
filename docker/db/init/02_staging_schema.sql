\set ON_ERROR_STOP 1

DROP SCHEMA IF EXISTS stg CASCADE;
CREATE SCHEMA stg;

-- ===== Reference masters =====
CREATE TABLE stg.currency (
  currency_code    CHAR(3),
  currency_name    TEXT,
  minor_unit       INT,
  source_system    TEXT,
  source_ref       TEXT,
  ingest_batch_id  TEXT,
  created_at       TIMESTAMP DEFAULT now(),
  updated_at       TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.exchange (
  exchange_code    TEXT,
  exchange_name    TEXT,
  source_system    TEXT,
  source_ref       TEXT,
  ingest_batch_id  TEXT,
  created_at       TIMESTAMP DEFAULT now(),
  updated_at       TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.price_source (
  price_source_code TEXT,
  price_source_name TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.strategy (
  strategy_code     TEXT,
  strategy_name     TEXT,
  strategy_category TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

-- ===== Core SCD2 dims =====
CREATE TABLE stg.portfolio (
  portfolio_code    TEXT,
  portfolio_name    TEXT,
  region            TEXT,
  entitlement_group TEXT,
  valid_from        DATE,
  valid_to          DATE,
  status            TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.account (
  account_code      TEXT,
  account_name      TEXT,
  region            TEXT,
  entitlement_group TEXT,
  valid_from        DATE,
  valid_to          DATE,
  status            TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.instrument (
  instrument_code   TEXT,
  instrument_type   TEXT,   -- 'EQUITY','BOND','FUT','OPT','FX','INDEX','OTHER'
  instrument_name   TEXT,
  exchange_code     TEXT,
  currency_code     CHAR(3),
  status            TEXT,
  valid_from        DATE,
  valid_to          DATE,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

-- ===== Subtype staging =====
CREATE TABLE stg.instrument_equity (
  instrument_code     TEXT,
  ticker              TEXT,
  cusip               TEXT,
  isin                TEXT,
  sedol               TEXT,
  exchange_country    TEXT,
  sector              TEXT,
  industry_group      TEXT,
  shares_outstanding  NUMERIC(20,2),
  dividend_yield      NUMERIC(10,6),
  dividend_currency   CHAR(3),
  dividend_frequency  TEXT,
  fiscal_year_end     DATE,
  listing_date        DATE,
  delisting_date      DATE,
  source_system       TEXT,
  source_ref          TEXT,
  ingest_batch_id     TEXT,
  created_at          TIMESTAMP DEFAULT now(),
  updated_at          TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.instrument_bond (
  instrument_code       TEXT,
  isin                  TEXT,
  cusip                 TEXT,
  issuer_name           TEXT,
  coupon_rate           NUMERIC(10,6),
  coupon_type           TEXT,
  coupon_frequency      TEXT,
  day_count_convention  TEXT,
  maturity_date         DATE,
  issue_date            DATE,
  dated_date            DATE,
  first_coupon_date     DATE,
  last_coupon_date      DATE,
  face_value            NUMERIC(20,2),
  currency_code         CHAR(3),
  country_of_issue      TEXT,
  call_type             TEXT,
  call_price            NUMERIC(20,6),
  source_system         TEXT,
  source_ref            TEXT,
  ingest_batch_id       TEXT,
  created_at            TIMESTAMP DEFAULT now(),
  updated_at            TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.instrument_futures (
  instrument_code    TEXT,
  contract_code      TEXT,
  underlying_symbol  TEXT,
  contract_size      NUMERIC(20,6),
  tick_size          NUMERIC(20,6),
  tick_value         NUMERIC(20,6),
  quote_currency     CHAR(3),
  delivery_month     TEXT,
  expiry_date        DATE,
  first_notice_date  DATE,
  last_trading_date  DATE,
  settlement_type    TEXT,      -- CASH/PHYSICAL
  exchange_code      TEXT,
  source_system      TEXT,
  source_ref         TEXT,
  ingest_batch_id    TEXT,
  created_at         TIMESTAMP DEFAULT now(),
  updated_at         TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.instrument_options (
  instrument_code    TEXT,
  option_symbol      TEXT,
  underlying_symbol  TEXT,
  option_type        TEXT,      -- CALL/PUT
  strike_price       NUMERIC(20,6),
  expiry_date        DATE,
  multiplier         NUMERIC(20,6),
  premium_currency   CHAR(3),
  exercise_style     TEXT,      -- AMERICAN/EUROPEAN
  settlement_type    TEXT,      -- CASH/PHYSICAL
  exchange_code      TEXT,
  source_system      TEXT,
  source_ref         TEXT,
  ingest_batch_id    TEXT,
  created_at         TIMESTAMP DEFAULT now(),
  updated_at         TIMESTAMP DEFAULT now()
);

-- ===== Bridges (SCD2) =====
CREATE TABLE stg.portfolio_strategy (
  portfolio_code   TEXT,
  strategy_code    TEXT,
  valid_from       DATE,
  valid_to         DATE,
  source_system    TEXT,
  source_ref       TEXT,
  ingest_batch_id  TEXT,
  created_at       TIMESTAMP DEFAULT now(),
  updated_at       TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.account_portfolio (
  account_code     TEXT,
  portfolio_code   TEXT,
  valid_from       DATE,
  valid_to         DATE,
  source_system    TEXT,
  source_ref       TEXT,
  ingest_batch_id  TEXT,
  created_at       TIMESTAMP DEFAULT now(),
  updated_at       TIMESTAMP DEFAULT now()
);

-- ===== Facts staging =====
CREATE TABLE stg.price (
  instrument_code    TEXT,
  price_source_code  TEXT,
  price_ts           TIMESTAMPTZ,
  price_type         TEXT,      -- MID/BID/ASK/CLOSE/THEO
  price              NUMERIC(28,10),
  currency_code      CHAR(3),
  is_eod_flag        BOOLEAN,
  source_system      TEXT,
  source_ref         TEXT,
  ingest_batch_id    TEXT,
  created_at         TIMESTAMP DEFAULT now(),
  updated_at         TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.fx_rate (
  currency_code     CHAR(3),
  rate_date         DATE,
  rate              NUMERIC(28,10),
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.trade_fill (
  execution_id       TEXT,
  trade_code         TEXT,
  account_code       TEXT,
  instrument_code    TEXT,
  trade_date         DATE,
  quantity           NUMERIC(28,6),
  price              NUMERIC(28,10),
  gross_amount       NUMERIC(28,10),
  net_amount         NUMERIC(28,10),
  broker_code        TEXT,
  counterparty_code  TEXT,
  source_system      TEXT,
  source_ref         TEXT,
  ingest_batch_id    TEXT,
  created_at         TIMESTAMP DEFAULT now(),
  updated_at         TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.position_snapshot (
  portfolio_code    TEXT,
  instrument_code   TEXT,
  position_date     DATE,
  quantity          NUMERIC(28,6),
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.cash_event (
  portfolio_code    TEXT,
  event_date        DATE,
  amount            NUMERIC(28,10),
  currency_code     CHAR(3),
  event_type        TEXT,
  notes             TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.position_adjustment (
  portfolio_code    TEXT,
  instrument_code   TEXT,
  effective_date    DATE,
  quantity_delta    NUMERIC(28,6),
  reason            TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

-- Optional: present in your data folder
CREATE TABLE stg.broker (
  broker_code       TEXT,
  broker_name       TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.counterparty (
  counterparty_code TEXT,
  counterparty_name TEXT,
  country           TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

CREATE TABLE stg.calendar (
  cal_date          DATE,
  is_business_day   BOOLEAN,
  market            TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);

-- (If you decide to ingest corp actions to feed adjustments)
CREATE TABLE stg.corporate_action_applied (
  instrument_code   TEXT,
  action_code       TEXT,
  ex_date           DATE,
  record_date       DATE,
  pay_date          DATE,
  factor            NUMERIC(28,10),
  amount            NUMERIC(28,10),
  currency_code     CHAR(3),
  notes             TEXT,
  source_system     TEXT,
  source_ref        TEXT,
  ingest_batch_id   TEXT,
  created_at        TIMESTAMP DEFAULT now(),
  updated_at        TIMESTAMP DEFAULT now()
);
