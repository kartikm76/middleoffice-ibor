INSERT INTO dim_portfolio (portfolio_id, portfolio_name, created_at, updated_at)
VALUES ('P-ALPHA', 'Alpha Growth Fund', now(), now());

INSERT INTO dim_instrument (instrument_id, instrument_name, asset_class, created_at, updated_at)
VALUES ('IBM', 'IBM Equity', 'Equity', now(), now());

INSERT INTO fact_trade (execution_id, portfolio_id, instrument_id, trade_date, quantity, price)
VALUES ('T1', 'P-ALPHA', 'IBM', current_date, 1000, 125.50);