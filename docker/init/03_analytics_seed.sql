-- =====================================================================
-- 03_analytics_seed.sql  (MVP seed for Performance & Attribution)
-- Safe to re-run: uses INSERT ... ON CONFLICT
-- Window: 2025-09-24 .. 2025-09-26
-- =====================================================================

-- 1) Benchmark catalog (demo)
INSERT INTO analytics.benchmarks (code, name, base_currency)
VALUES ('SPX','S&P 500 (demo)','USD')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- 2) Daily prices (IBM, AAPL) in USD
INSERT INTO analytics.daily_prices (instrument_id, price_as_of_date, close_price, currency, fx_to_base)
SELECT inst_id, d::date, price, 'USD', 1.0
FROM (
  -- IBM
  SELECT (SELECT id FROM instruments WHERE ticker = 'IBM') AS inst_id, '2025-09-24'::date d, 195.00::numeric price UNION ALL
  SELECT (SELECT id FROM instruments WHERE ticker = 'IBM'), '2025-09-25', 197.34 UNION ALL
  SELECT (SELECT id FROM instruments WHERE ticker = 'IBM'), '2025-09-26', 196.40 UNION ALL
  -- AAPL
  SELECT (SELECT id FROM instruments WHERE ticker = 'AAPL'), '2025-09-24', 220.10 UNION ALL
  SELECT (SELECT id FROM instruments WHERE ticker = 'AAPL'), '2025-09-25', 221.00 UNION ALL
  SELECT (SELECT id FROM instruments WHERE ticker = 'AAPL'), '2025-09-26', 223.25
) p
ON CONFLICT (instrument_id, price_as_of_date) DO UPDATE
SET close_price = EXCLUDED.close_price,
    currency    = EXCLUDED.currency,
    fx_to_base  = EXCLUDED.fx_to_base;

-- 3) Holdings snapshot (weights) — ALPHA (60/40), BETA (50/50), segment TECH
--    mv_base is computed using the price for that day to keep totals sensible.
INSERT INTO analytics.holdings_daily
  (portfolio_id, holding_as_of_date, instrument_id, quantity, mv_base, weight, segment_key)
SELECT * FROM (
  -- ALPHA: IBM 60%, AAPL 40%
  SELECT
    (SELECT id FROM portfolios  WHERE code='ALPHA')            AS portfolio_id,
    gs::date                                                   AS holding_as_of_date,
    (SELECT id FROM instruments WHERE ticker='IBM')            AS instrument_id,
    1000::numeric                                             AS quantity,
    1000 * (SELECT close_price*COALESCE(fx_to_base,1)
            FROM analytics.daily_prices
            WHERE instrument_id = (SELECT id FROM instruments WHERE ticker='IBM')
              AND price_as_of_date = gs::date)                AS mv_base,
    0.60::numeric                                             AS weight,
    'TECH'                                                    AS segment_key
  FROM generate_series('2025-09-24'::date, '2025-09-26', '1 day') gs
  UNION ALL
  SELECT
    (SELECT id FROM portfolios  WHERE code='ALPHA'),
    gs::date,
    (SELECT id FROM instruments WHERE ticker='AAPL'),
    800::numeric,
    800 * (SELECT close_price*COALESCE(fx_to_base,1)
           FROM analytics.daily_prices
           WHERE instrument_id = (SELECT id FROM instruments WHERE ticker='AAPL')
             AND price_as_of_date = gs::date),
    0.40::numeric,
    'TECH'
  FROM generate_series('2025-09-24'::date, '2025-09-26', '1 day') gs

  -- BETA: IBM 50%, AAPL 50%
  UNION ALL
  SELECT
    (SELECT id FROM portfolios  WHERE code='BETA'),
    gs::date,
    (SELECT id FROM instruments WHERE ticker='IBM'),
    900::numeric,
    900 * (SELECT close_price*COALESCE(fx_to_base,1)
           FROM analytics.daily_prices
           WHERE instrument_id = (SELECT id FROM instruments WHERE ticker='IBM')
             AND price_as_of_date = gs::date),
    0.50::numeric,
    'TECH'
  FROM generate_series('2025-09-24'::date, '2025-09-26', '1 day') gs
  UNION ALL
  SELECT
    (SELECT id FROM portfolios  WHERE code='BETA'),
    gs::date,
    (SELECT id FROM instruments WHERE ticker='AAPL'),
    900::numeric,
    900 * (SELECT close_price*COALESCE(fx_to_base,1)
           FROM analytics.daily_prices
           WHERE instrument_id = (SELECT id FROM instruments WHERE ticker='AAPL')
             AND price_as_of_date = gs::date),
    0.50::numeric,
    'TECH'
  FROM generate_series('2025-09-24'::date, '2025-09-26', '1 day') gs
) s
ON CONFLICT (portfolio_id, holding_as_of_date, instrument_id) DO UPDATE
SET quantity   = EXCLUDED.quantity,
    mv_base    = EXCLUDED.mv_base,
    weight     = EXCLUDED.weight,
    segment_key= EXCLUDED.segment_key;

-- 4) Benchmark segments (TECH, ENERGY) for SPX
--    ENERGY is present only in benchmark → creates a clear allocation effect.
INSERT INTO analytics.benchmark_segments_daily
  (benchmark_id, benchmark_as_of_date, segment_key, benchmark_weight, benchmark_return_segment)
SELECT
  (SELECT id FROM analytics.benchmarks WHERE code='SPX') AS benchmark_id,
  d::date                                                AS benchmark_as_of_date,
  seg                                                    AS segment_key,
  w                                                      AS benchmark_weight,
  r                                                      AS benchmark_return_segment
FROM (
  VALUES
    -- date,      segment,  weight, return
    ('2025-09-24', 'TECH',   0.25,   0.0040),
    ('2025-09-24', 'ENERGY', 0.08,  -0.0020),
    ('2025-09-25', 'TECH',   0.25,   0.0090),
    ('2025-09-25', 'ENERGY', 0.08,   0.0030),
    ('2025-09-26', 'TECH',   0.25,  -0.0040),
    ('2025-09-26', 'ENERGY', 0.08,   0.0010)
) v(d, seg, w, r)
ON CONFLICT (benchmark_id, benchmark_as_of_date, segment_key) DO UPDATE
SET benchmark_weight          = EXCLUDED.benchmark_weight,
    benchmark_return_segment  = EXCLUDED.benchmark_return_segment;

-- 5) Security daily returns (per portfolio/instrument/day)
--    r_i,t = (P_t - P_{t-1}) / P_{t-1}  (dividends not modeled in this seed)
INSERT INTO analytics.returns_security_daily
  (portfolio_id, instrument_id, return_as_of_date, return, segment_key)
SELECT
  h.portfolio_id,
  h.instrument_id,
  p_t.price_as_of_date                          AS return_as_of_date,
  CASE WHEN p_y.close_price IS NULL OR p_y.close_price = 0
       THEN 0
       ELSE (p_t.close_price - p_y.close_price) / p_y.close_price
  END                                           AS return,
  h.segment_key
FROM analytics.holdings_daily h
JOIN analytics.daily_prices p_t
  ON p_t.instrument_id    = h.instrument_id
 AND p_t.price_as_of_date = h.holding_as_of_date
LEFT JOIN analytics.daily_prices p_y
  ON p_y.instrument_id    = h.instrument_id
 AND p_y.price_as_of_date = h.holding_as_of_date - INTERVAL '1 day'
ON CONFLICT (portfolio_id, instrument_id, return_as_of_date) DO UPDATE
SET return      = EXCLUDED.return,
    segment_key = EXCLUDED.segment_key;

-- 6) Portfolio daily TWRR
INSERT INTO analytics.returns_portfolio_daily
  (portfolio_id, return_as_of_date, twrr, total_mv_base)
SELECT
  h.portfolio_id,
  h.holding_as_of_date                  AS return_as_of_date,
  SUM(h.weight * rsd.return)            AS twrr,
  SUM(h.mv_base)                        AS total_mv_base
FROM analytics.holdings_daily h
JOIN analytics.returns_security_daily rsd
  ON rsd.portfolio_id      = h.portfolio_id
 AND rsd.instrument_id     = h.instrument_id
 AND rsd.return_as_of_date = h.holding_as_of_date
GROUP BY h.portfolio_id, h.holding_as_of_date
ON CONFLICT (portfolio_id, return_as_of_date) DO UPDATE
SET twrr         = EXCLUDED.twrr,
    total_mv_base= EXCLUDED.total_mv_base;

-- 7) Brinson-Fachler attribution (daily, by segment)
--    Allocation:   (wP - wB) * (rB_s - rB_total)
--    Selection:    wB * (rP_s - rB_s)
--    Interaction:  (wP - wB) * (rP_s - rB_s)
--    rP_s is portfolio's segment return (weighted avg of security returns within segment)
WITH
bseg AS (
  SELECT benchmark_id, benchmark_as_of_date, segment_key,
         benchmark_weight, benchmark_return_segment
  FROM analytics.benchmark_segments_daily
),
btot AS (
  SELECT benchmark_id, benchmark_as_of_date,
         SUM(benchmark_weight * benchmark_return_segment) AS rB_total
  FROM bseg
  GROUP BY benchmark_id, benchmark_as_of_date
),
pf_seg AS (
  SELECT
    h.portfolio_id,
    h.holding_as_of_date,
    h.segment_key,
    SUM(h.weight) AS wP_seg,
    CASE WHEN SUM(h.weight) = 0 THEN 0
         ELSE SUM(h.weight * rsd.return) / SUM(h.weight)
    END AS rP_seg
  FROM analytics.holdings_daily h
  JOIN analytics.returns_security_daily rsd
    ON rsd.portfolio_id      = h.portfolio_id
   AND rsd.instrument_id     = h.instrument_id
   AND rsd.return_as_of_date = h.holding_as_of_date
  GROUP BY h.portfolio_id, h.holding_as_of_date, h.segment_key
),
seg_union AS (
  -- All segments present in benchmark (drives attribution set)
  SELECT DISTINCT segment_key FROM bseg
),
dates AS (
  SELECT DISTINCT holding_as_of_date FROM analytics.holdings_daily
)
INSERT INTO analytics.attribution_brinson_daily
  (portfolio_id, benchmark_id, attribution_as_of_date, segment_key,
   alloc_contrib, sel_contrib, int_contrib, total_contrib)
SELECT
  p.portfolio_id,
  bm.benchmark_id,
  d.holding_as_of_date                                 AS attribution_as_of_date,
  s.segment_key,
  (x.wP - x.wB) * (x.rB_s - x.rB_total)                AS alloc_contrib,
  x.wB * (x.rP_s - x.rB_s)                             AS sel_contrib,
  (x.wP - x.wB) * (x.rP_s - x.rB_s)                    AS int_contrib,
  (x.wP - x.wB) * (x.rB_s - x.rB_total)
    + x.wB * (x.rP_s - x.rB_s)
    + (x.wP - x.wB) * (x.rP_s - x.rB_s)                AS total_contrib
FROM dates d
CROSS JOIN (SELECT DISTINCT portfolio_id FROM analytics.holdings_daily) p
CROSS JOIN (SELECT id AS benchmark_id FROM analytics.benchmarks WHERE code='SPX') bm
CROSS JOIN seg_union s
LEFT JOIN bseg b
       ON b.benchmark_id         = bm.benchmark_id
      AND b.benchmark_as_of_date = d.holding_as_of_date
      AND b.segment_key          = s.segment_key
LEFT JOIN btot bt
       ON bt.benchmark_id        = bm.benchmark_id
      AND bt.benchmark_as_of_date= d.holding_as_of_date
LEFT JOIN pf_seg ps
       ON ps.portfolio_id        = p.portfolio_id
      AND ps.holding_as_of_date  = d.holding_as_of_date
      AND ps.segment_key         = s.segment_key
-- Coalesce after joins
CROSS JOIN LATERAL (
  SELECT
    COALESCE(ps.wP_seg, 0)                    AS wP,
    COALESCE(b.benchmark_weight, 0)           AS wB,
    COALESCE(ps.rP_seg, 0)                    AS rP_s,
    COALESCE(b.benchmark_return_segment, 0)   AS rB_s,
    COALESCE(bt.rB_total, 0)                  AS rB_total
) x
ON CONFLICT (portfolio_id, benchmark_id, attribution_as_of_date, segment_key) DO UPDATE
SET alloc_contrib = EXCLUDED.alloc_contrib,
    sel_contrib   = EXCLUDED.sel_contrib,
    int_contrib   = EXCLUDED.int_contrib,
    total_contrib = EXCLUDED.total_contrib;

-- =====================================================================
-- Quick sanity queries (optional)
-- SELECT * FROM analytics.returns_portfolio_daily ORDER BY portfolio_id, return_as_of_date;
-- SELECT * FROM analytics.attribution_brinson_daily ORDER BY portfolio_id, attribution_as_of_date, segment_key;
-- =====================================================================
