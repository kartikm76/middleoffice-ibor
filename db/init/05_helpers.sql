\set ON_ERROR_STOP 1

-- Keep everything under ibor schema
SET search_path TO ibor, public;

-- =========================================================
-- Simple resolvers (IDs by code)
-- =========================================================
CREATE OR REPLACE FUNCTION fn_strategy_vid(p_strategy_code TEXT)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT s.strategy_vid
  FROM ibor.dim_strategy s
  WHERE s.strategy_code = p_strategy_code
$$;

CREATE OR REPLACE FUNCTION fn_price_source_vid(p_code TEXT)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT ps.price_source_vid
  FROM ibor.dim_price_source ps
  WHERE ps.price_source_code = p_code
$$;

-- =========================================================
-- SCD2 point-in-time VID lookups by business code + as-of DATE
-- =========================================================
CREATE OR REPLACE FUNCTION fn_instrument_vid_at(p_instrument_code TEXT, p_as_of DATE)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT i.instrument_vid
  FROM ibor.dim_instrument i
  WHERE i.instrument_code = p_instrument_code
    AND i.valid_from <= p_as_of
    AND i.valid_to   >= p_as_of
  ORDER BY i.valid_from DESC
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION fn_portfolio_vid_at(p_portfolio_code TEXT, p_as_of DATE)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT p.portfolio_vid
  FROM ibor.dim_portfolio p
  WHERE p.portfolio_code = p_portfolio_code
    AND p.valid_from <= p_as_of
    AND p.valid_to   >= p_as_of
  ORDER BY p.valid_from DESC
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION fn_account_vid_at(p_account_code TEXT, p_as_of DATE)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT a.account_vid
  FROM ibor.dim_account a
  WHERE a.account_code = p_account_code
    AND a.valid_from <= p_as_of
    AND a.valid_to   >= p_as_of
  ORDER BY a.valid_from DESC
  LIMIT 1
$$;

-- =========================================================
-- Convenience: current (latest) VID by code (when PIT date is not relevant)
-- =========================================================
CREATE OR REPLACE FUNCTION fn_instrument_vid_current(p_instrument_code TEXT)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT i.instrument_vid
  FROM ibor.dim_instrument i
  WHERE i.instrument_code = p_instrument_code
    AND i.is_current = TRUE
  ORDER BY i.valid_from DESC
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION fn_portfolio_vid_current(p_portfolio_code TEXT)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT p.portfolio_vid
  FROM ibor.dim_portfolio p
  WHERE p.portfolio_code = p_portfolio_code
    AND p.is_current = TRUE
  ORDER BY p.valid_from DESC
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION fn_account_vid_current(p_account_code TEXT)
RETURNS BIGINT LANGUAGE sql STABLE AS $$
  SELECT a.account_vid
  FROM ibor.dim_account a
  WHERE a.account_code = p_account_code
    AND a.is_current = TRUE
  ORDER BY a.valid_from DESC
  LIMIT 1
$$;

-- Pick direct pair at/before date
CREATE OR REPLACE FUNCTION ibor.fn_pick_fx_direct(
    p_from CHAR(3), p_to CHAR(3), p_at DATE
) RETURNS NUMERIC LANGUAGE sql AS $$
SELECT rate
FROM ibor.fact_fx_rate
WHERE from_currency_code = p_from
  AND to_currency_code   = p_to
  AND rate_date <= p_at
ORDER BY rate_date DESC
LIMIT 1;
$$;

-- Triangulate via USD if direct missing
CREATE OR REPLACE FUNCTION ibor.fn_pick_fx_triangulated_via_usd(
    p_from CHAR(3), p_to CHAR(3), p_at DATE
) RETURNS NUMERIC LANGUAGE sql AS $$
WITH
    r1 AS (SELECT ibor.fn_pick_fx_direct(p_from, 'USD', p_at)  AS a),
    r2 AS (SELECT ibor.fn_pick_fx_direct(p_to,   'USD', p_at)  AS b)
SELECT CASE
           WHEN (SELECT a FROM r1) IS NULL OR (SELECT b FROM r2) IS NULL THEN NULL
           ELSE (SELECT a FROM r1) / (SELECT b FROM r2)
           END;
$$;

-- Unified picker: direct else triangulated
CREATE OR REPLACE FUNCTION ibor.fn_pick_fx_at_or_before(
    p_from CHAR(3), p_to CHAR(3), p_at DATE
) RETURNS NUMERIC LANGUAGE sql AS $$
SELECT COALESCE(
               ibor.fn_pick_fx_direct(p_from, p_to, p_at),
               ibor.fn_pick_fx_triangulated_via_usd(p_from, p_to, p_at)
       );
$$;

-- =========================================================
-- Sanity helpers
-- =========================================================
-- Returns TRUE if a code exists in its reference table.
CREATE OR REPLACE FUNCTION fn_exists_currency(p_code CHAR(3))
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM ibor.dim_currency c WHERE c.currency_code = p_code)
$$;

CREATE OR REPLACE FUNCTION fn_exists_exchange(p_code TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM ibor.dim_exchange e WHERE e.exchange_code = p_code)
$$;
