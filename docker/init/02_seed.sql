-----------------------------------------------------==
-- 02_seed.sql  (idempotent)
-- Seeds portfolios, instruments, trades, and cash events
-----------------------------------------------------==

-----------
-- Portfolios
-----------
INSERT INTO portfolios (code, name) VALUES
  ('ALPHA', 'Alpha Fund'),
  ('BETA',  'Beta Fund'),
  ('GM',    'Global Macro')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

------------
-- Instruments
------------
INSERT INTO instruments (ticker, asset_class, currency, price_last, price_time) VALUES
  ('IBM',  'EQUITY', 'USD', 158.60, now()),
  ('AAPL', 'EQUITY', 'USD', 232.10, now()),
  ('US91282CJK11', 'BOND', 'USD', 99.10, now())
ON CONFLICT (ticker) DO UPDATE
  SET asset_class = EXCLUDED.asset_class,
      currency    = EXCLUDED.currency,
      price_last  = EXCLUDED.price_last,
      price_time  = EXCLUDED.price_time;

-------------------------
-- Clean existing seed data
-------------------------
-- Remove seed trades by their known trade_ids (so we can re-run safely)
DELETE FROM trades
WHERE trade_id IN ('T1001','T1002','T1003','T1004','T2001');

-- Remove seed cash events by recognizable descriptions
DELETE FROM cash_events
WHERE description IN ('Bond settlement inflow','Fees','Dividend','Wire out');

--------
-- Trades
--------
INSERT INTO trades (trade_id, portfolio_id, instrument_id, side, qty, price, trade_dt, settle_dt, fees) VALUES
  (
    'T1001',
    (SELECT id FROM portfolios  WHERE code   = 'ALPHA'),
    (SELECT id FROM instruments WHERE ticker = 'IBM'),
    'BUY', 1000, 200.00, '2025-09-10T14:30:00Z', '2025-09-12T00:00:00Z', 50
  ),
  (
    'T1002',
    (SELECT id FROM portfolios  WHERE code   = 'GM'),
    (SELECT id FROM instruments WHERE ticker = 'IBM'),
    'BUY', 4500, 158.30, '2025-09-11T15:01:00Z', '2025-09-13T00:00:00Z', 230
  ),
  (
    'T1003',
    (SELECT id FROM portfolios  WHERE code   = 'ALPHA'),
    (SELECT id FROM instruments WHERE ticker = 'AAPL'),
    'SELL', 300, 232.10, '2025-09-10T16:15:00Z', '2025-09-12T00:00:00Z', 20
  ),
  (
    'T1004',
    (SELECT id FROM portfolios  WHERE code   = 'BETA'),
    (SELECT id FROM instruments WHERE ticker = 'IBM'),
    'SELL', 600, 157.20, '2025-09-12T13:05:00Z', '2025-09-14T00:00:00Z', 25
  ),
  (
    'T2001',
    (SELECT id FROM portfolios  WHERE code   = 'ALPHA'),
    (SELECT id FROM instruments WHERE ticker = 'US91282CJK11'),
    'BUY', 100000, 99.10, '2025-09-09T12:00:00Z', '2025-09-12T00:00:00Z', 0
  );

--------------
-- Cash events
--------------
INSERT INTO cash_events (portfolio_id, ccy, value_dt, amount, description) VALUES
  ((SELECT id FROM portfolios WHERE code = 'ALPHA'), 'USD', current_date + 1,  250000, 'Bond settlement inflow'),
  ((SELECT id FROM portfolios WHERE code = 'ALPHA'), 'USD', current_date + 2,  -15000, 'Fees'),
  ((SELECT id FROM portfolios WHERE code = 'GM'),    'USD', current_date + 3,   12000, 'Dividend'),
  ((SELECT id FROM portfolios WHERE code = 'BETA'),  'USD', current_date + 5,  -50000, 'Wire out');

-- Optional: quick checks (comment out if running non-interactively)
-- SELECT * FROM portfolios ORDER BY id;
-- SELECT * FROM instruments ORDER BY id;
-- SELECT p.code, i.ticker, t.side, t.qty, t.price FROM trades t
--   JOIN portfolios p  ON p.id = t.portfolio_id
--   JOIN instruments i ON i.id = t.instrument_id
-- ORDER BY trade_dt;
