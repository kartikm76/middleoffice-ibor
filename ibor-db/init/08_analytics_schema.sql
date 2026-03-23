-- =====================================================================
-- ANALYTICS SCHEMA
-- Pre-computed views and tables for portfolio analytics endpoints.
-- =====================================================================

-- Create analytics schema
DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;

-- ── Convenience views in public schema ───────────────────────────────
-- The analytics repositories reference `portfolios` and `instruments`
-- without a schema qualifier (uses default search_path).

CREATE OR REPLACE VIEW public.portfolios AS
    SELECT portfolio_vid AS id, portfolio_code AS code, portfolio_name AS name
    FROM ibor.dim_portfolio;

CREATE OR REPLACE VIEW public.instruments AS
    SELECT di.instrument_vid AS id,
           di.instrument_code AS code,
           COALESCE(die.ticker, di.instrument_code) AS ticker
    FROM ibor.dim_instrument di
    LEFT JOIN ibor.dim_instrument_equity die USING (instrument_vid)
    WHERE di.is_current = TRUE;

-- ── Benchmarks ────────────────────────────────────────────────────────
CREATE TABLE analytics.benchmarks (
    id            BIGSERIAL PRIMARY KEY,
    code          TEXT NOT NULL UNIQUE,
    name          TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed one benchmark for demo
INSERT INTO analytics.benchmarks (code, name) VALUES ('SPX', 'S&P 500 Index');

-- ── Daily portfolio returns ───────────────────────────────────────────
-- Populated from fact_position_snapshot + fact_price via the view below
CREATE TABLE analytics.returns_portfolio_daily (
    id              BIGSERIAL PRIMARY KEY,
    portfolio_id    BIGINT NOT NULL,  -- FK to public.portfolios(id)
    return_as_of_date DATE NOT NULL,
    twrr            DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_mv_base   DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE (portfolio_id, return_as_of_date)
);

-- Backfill: insert a row per (portfolio, price_date) pair with placeholder returns
INSERT INTO analytics.returns_portfolio_daily (portfolio_id, return_as_of_date, twrr, total_mv_base)
SELECT DISTINCT
    p.portfolio_vid,
    fps.position_date,
    0.0   AS twrr,
    0.0   AS total_mv_base
FROM ibor.fact_position_snapshot fps
JOIN ibor.dim_portfolio p ON p.portfolio_vid = fps.portfolio_vid
ON CONFLICT DO NOTHING;

-- ── Daily holdings ────────────────────────────────────────────────────
CREATE TABLE analytics.holdings_daily (
    id                 BIGSERIAL PRIMARY KEY,
    portfolio_id       BIGINT NOT NULL,
    instrument_id      BIGINT NOT NULL,
    holding_as_of_date DATE NOT NULL,
    segment_key        TEXT,
    weight             DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE (portfolio_id, instrument_id, holding_as_of_date)
);

-- Backfill: one row per (portfolio, instrument, date) from position snapshots
INSERT INTO analytics.holdings_daily (portfolio_id, instrument_id, holding_as_of_date, segment_key, weight)
SELECT
    fps.portfolio_vid,
    fps.instrument_vid,
    fps.position_date,
    COALESCE(die.sector, di.instrument_type) AS segment_key,
    0.0 AS weight
FROM ibor.fact_position_snapshot fps
JOIN ibor.dim_instrument di      ON di.instrument_vid = fps.instrument_vid
LEFT JOIN ibor.dim_instrument_equity die ON die.instrument_vid = fps.instrument_vid
ON CONFLICT DO NOTHING;

-- ── Daily security returns ────────────────────────────────────────────
CREATE TABLE analytics.returns_security_daily (
    id                 BIGSERIAL PRIMARY KEY,
    portfolio_id       BIGINT NOT NULL,
    instrument_id      BIGINT NOT NULL,
    return_as_of_date  DATE NOT NULL,
    return             DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE (portfolio_id, instrument_id, return_as_of_date)
);

-- Backfill: same shape as holdings
INSERT INTO analytics.returns_security_daily (portfolio_id, instrument_id, return_as_of_date, return)
SELECT portfolio_id, instrument_id, holding_as_of_date, 0.0
FROM analytics.holdings_daily
ON CONFLICT DO NOTHING;

-- ── Benchmark segment returns ─────────────────────────────────────────
CREATE TABLE analytics.benchmark_segments_daily (
    id                      BIGSERIAL PRIMARY KEY,
    benchmark_id            BIGINT NOT NULL REFERENCES analytics.benchmarks(id),
    benchmark_as_of_date    DATE NOT NULL,
    segment_key             TEXT NOT NULL,
    benchmark_weight        DOUBLE PRECISION NOT NULL DEFAULT 0,
    benchmark_return_segment DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE (benchmark_id, benchmark_as_of_date, segment_key)
);

-- ── Brinson attribution daily ─────────────────────────────────────────
CREATE TABLE analytics.attribution_brinson_daily (
    id                    BIGSERIAL PRIMARY KEY,
    portfolio_id          BIGINT NOT NULL,
    benchmark_id          BIGINT NOT NULL REFERENCES analytics.benchmarks(id),
    attribution_as_of_date DATE NOT NULL,
    segment_key           TEXT NOT NULL,
    alloc_contrib         DOUBLE PRECISION NOT NULL DEFAULT 0,
    sel_contrib           DOUBLE PRECISION NOT NULL DEFAULT 0,
    int_contrib           DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_contrib         DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE (portfolio_id, benchmark_id, attribution_as_of_date, segment_key)
);
