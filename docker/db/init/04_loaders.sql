-- Purpose: Load from stg.* into ibor.* using surrogate keys and SCD2 where needed.
-- Assumptions:
--   - Business dates are DATE; audit timestamps are TIMESTAMP WITHOUT TIME ZONE.
--   - Triggers will set created_at/updated_at; some functions also update updated_at explicitly.
--   - Helper resolvers (fn_resolve_*) are defined in 05_helpers.sql.

\set ON_ERROR_STOP 1
SET search_path=ibor, public;

-- =====================================================================
-- 04_loaders.sql
-- Loaders from stg.* -> ibor.* (reference, SCD2 dims, bridges, facts)
-- Idempotent where possible; staging rows deleted after load.
-- =====================================================================

-- =========================
-- Reference (non-SCD) dims
-- =========================
CREATE OR REPLACE FUNCTION ibor.load_currency_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH up AS (
    INSERT INTO ibor.dim_currency(currency_code, currency_name, minor_unit)
    SELECT currency_code, currency_name, minor_unit
    FROM stg.currency
    ON CONFLICT (currency_code) DO UPDATE
      SET currency_name = EXCLUDED.currency_name,
          minor_unit    = EXCLUDED.minor_unit,
          updated_at    = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;
  DELETE FROM stg.currency;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_exchange_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH up AS (
    INSERT INTO ibor.dim_exchange(exchange_code, exchange_name)
    SELECT exchange_code, exchange_name
    FROM stg.exchange
    ON CONFLICT (exchange_code) DO UPDATE
      SET exchange_name = EXCLUDED.exchange_name,
          updated_at    = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;
  DELETE FROM stg.exchange;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_price_source_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH up AS (
    INSERT INTO ibor.dim_price_source(price_source_code, price_source_name)
    SELECT price_source_code, price_source_name
    FROM stg.price_source
    ON CONFLICT (price_source_code) DO UPDATE
      SET price_source_name = EXCLUDED.price_source_name,
          updated_at        = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;
  DELETE FROM stg.price_source;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_strategy_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH up AS (
    INSERT INTO ibor.dim_strategy(strategy_code, strategy_name, strategy_category, status)
    SELECT strategy_code, strategy_name, strategy_category, 'ACTIVE'
    FROM stg.strategy
    ON CONFLICT (strategy_code) DO UPDATE
      SET strategy_name     = EXCLUDED.strategy_name,
          strategy_category = EXCLUDED.strategy_category,
          updated_at        = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;
  DELETE FROM stg.strategy;
  RETURN COALESCE(c,0);
END $$;

-- =========================
-- SCD2: portfolio / account
-- =========================
CREATE OR REPLACE FUNCTION ibor.load_portfolio_scd2()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD;
BEGIN
  FOR r IN
    SELECT portfolio_code, portfolio_name, region, entitlement_group,
           COALESCE(valid_from, CURRENT_DATE) vf,
           COALESCE(valid_to, DATE '9999-12-31') vt,
           COALESCE(status,'ACTIVE') status
    FROM stg.portfolio
  LOOP
    -- Close any current slice strictly before new vf
    UPDATE ibor.dim_portfolio
      SET valid_to = r.vf - 1, is_current = FALSE, updated_at = now()
      WHERE portfolio_code = r.portfolio_code
        AND is_current = TRUE
        AND valid_from < r.vf;

    -- Insert new slice
    INSERT INTO ibor.dim_portfolio(
      portfolio_code, portfolio_name, region, entitlement_group,
      status, valid_from, valid_to, is_current
    )
    VALUES (
      r.portfolio_code, r.portfolio_name, r.region, r.entitlement_group,
      r.status, r.vf, r.vt, (r.vt = DATE '9999-12-31')
    )
    ON CONFLICT (portfolio_code, valid_from) DO NOTHING;

    c := c + 1;
  END LOOP;

  DELETE FROM stg.portfolio;
  RETURN c;
END $$;

CREATE OR REPLACE FUNCTION ibor.load_account_scd2()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD;
BEGIN
  FOR r IN
    SELECT account_code, account_name, region, entitlement_group,
           COALESCE(valid_from, CURRENT_DATE) vf,
           COALESCE(valid_to, DATE '9999-12-31') vt,
           COALESCE(status,'ACTIVE') status
    FROM stg.account
  LOOP
    UPDATE ibor.dim_account
      SET valid_to = r.vf - 1, is_current = FALSE, updated_at = now()
      WHERE account_code = r.account_code
        AND is_current = TRUE
        AND valid_from < r.vf;

    INSERT INTO ibor.dim_account(
      account_code, account_name, region, entitlement_group,
      status, valid_from, valid_to, is_current
    )
    VALUES (
      r.account_code, r.account_name, r.region, r.entitlement_group,
      r.status, r.vf, r.vt, (r.vt = DATE '9999-12-31')
    )
    ON CONFLICT (account_code, valid_from) DO NOTHING;

    c := c + 1;
  END LOOP;

  DELETE FROM stg.account;
  RETURN c;
END $$;

-- =========================
-- SCD2: instrument core
-- =========================
CREATE OR REPLACE FUNCTION ibor.load_instrument_scd2()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD;
BEGIN
  FOR r IN
    SELECT instrument_code, instrument_type, instrument_name,
           exchange_code, currency_code,
           COALESCE(status,'ACTIVE') status,
           COALESCE(valid_from, CURRENT_DATE) vf,
           COALESCE(valid_to, DATE '9999-12-31') vt
    FROM stg.instrument
  LOOP
    UPDATE ibor.dim_instrument
      SET valid_to = r.vf - 1, is_current = FALSE, updated_at = now()
      WHERE instrument_code = r.instrument_code
        AND is_current = TRUE
        AND valid_from < r.vf;

    INSERT INTO ibor.dim_instrument(
      instrument_code, instrument_type, instrument_name, exchange_code, currency_code,
      status, valid_from, valid_to, is_current
    )
    VALUES (
      r.instrument_code, r.instrument_type, r.instrument_name, r.exchange_code, r.currency_code,
      r.status, r.vf, r.vt, (r.vt = DATE '9999-12-31')
    )
    ON CONFLICT (instrument_code, valid_from) DO NOTHING;

    c := c + 1;
  END LOOP;

  DELETE FROM stg.instrument;
  RETURN c;
END $$;

-- =========================
-- Subtype upserts (1:1 to current instrument_vid)
-- =========================
CREATE OR REPLACE FUNCTION ibor.load_instrument_equity_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD; v BIGINT;
BEGIN
  FOR r IN SELECT * FROM stg.instrument_equity LOOP
    SELECT instrument_vid INTO v
    FROM ibor.dim_instrument
    WHERE instrument_code = r.instrument_code
      AND is_current = TRUE
    ORDER BY valid_from DESC LIMIT 1;

    IF v IS NOT NULL THEN
      INSERT INTO ibor.dim_instrument_equity(
        instrument_vid, ticker, cusip, isin, sedol, exchange_country, sector, industry_group,
        shares_outstanding, dividend_yield, dividend_currency, dividend_frequency,
        fiscal_year_end, listing_date, delisting_date
      )
      VALUES (
        v, r.ticker, r.cusip, r.isin, r.sedol, r.exchange_country, r.sector, r.industry_group,
        r.shares_outstanding, r.dividend_yield, r.dividend_currency, r.dividend_frequency,
        r.fiscal_year_end, r.listing_date, r.delisting_date
      )
      ON CONFLICT (instrument_vid) DO UPDATE
        SET ticker             = r.ticker,
            cusip              = r.cusip,
            isin               = r.isin,
            sedol              = r.sedol,
            exchange_country   = r.exchange_country,
            sector             = r.sector,
            industry_group     = r.industry_group,
            shares_outstanding = r.shares_outstanding,
            dividend_yield     = r.dividend_yield,
            dividend_currency  = r.dividend_currency,
            dividend_frequency = r.dividend_frequency,
            fiscal_year_end    = r.fiscal_year_end,
            listing_date       = r.listing_date,
            delisting_date     = r.delisting_date,
            updated_at         = now();
      c := c + 1;
    END IF;
  END LOOP;

  DELETE FROM stg.instrument_equity;
  RETURN c;
END $$;

CREATE OR REPLACE FUNCTION ibor.load_instrument_bond_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD; v BIGINT;
BEGIN
  FOR r IN SELECT * FROM stg.instrument_bond LOOP
    SELECT instrument_vid INTO v
    FROM ibor.dim_instrument
    WHERE instrument_code = r.instrument_code
      AND is_current = TRUE
    ORDER BY valid_from DESC LIMIT 1;

    IF v IS NOT NULL THEN
      INSERT INTO ibor.dim_instrument_bond(
        instrument_vid, isin, cusip, issuer_name, coupon_rate, coupon_type, coupon_frequency,
        day_count_convention, maturity_date, issue_date, dated_date, first_coupon_date, last_coupon_date,
        face_value, currency_code, country_of_issue, call_type, call_price
      )
      VALUES (
        v, r.isin, r.cusip, r.issuer_name, r.coupon_rate, r.coupon_type, r.coupon_frequency,
        r.day_count_convention, r.maturity_date, r.issue_date, r.dated_date, r.first_coupon_date, r.last_coupon_date,
        r.face_value, r.currency_code, r.country_of_issue, r.call_type, r.call_price
      )
      ON CONFLICT (instrument_vid) DO UPDATE
        SET isin                 = r.isin,
            cusip                = r.cusip,
            issuer_name          = r.issuer_name,
            coupon_rate          = r.coupon_rate,
            coupon_type          = r.coupon_type,
            coupon_frequency     = r.coupon_frequency,
            day_count_convention = r.day_count_convention,
            maturity_date        = r.maturity_date,
            issue_date           = r.issue_date,
            dated_date           = r.dated_date,
            first_coupon_date    = r.first_coupon_date,
            last_coupon_date     = r.last_coupon_date,
            face_value           = r.face_value,
            currency_code        = r.currency_code,
            country_of_issue     = r.country_of_issue,
            call_type            = r.call_type,
            call_price           = r.call_price,
            updated_at           = now();
      c := c + 1;
    END IF;
  END LOOP;

  DELETE FROM stg.instrument_bond;
  RETURN c;
END $$;

CREATE OR REPLACE FUNCTION ibor.load_instrument_futures_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD; v BIGINT;
BEGIN
  FOR r IN SELECT * FROM stg.instrument_futures LOOP
    SELECT instrument_vid INTO v
    FROM ibor.dim_instrument
    WHERE instrument_code = r.instrument_code
      AND is_current = TRUE
    ORDER BY valid_from DESC LIMIT 1;

    IF v IS NOT NULL THEN
      INSERT INTO ibor.dim_instrument_futures(
        instrument_vid, contract_code, underlying_symbol, contract_size, tick_size, tick_value,
        quote_currency, delivery_month, expiry_date, first_notice_date, last_trading_date,
        settlement_type, exchange_code
      )
      VALUES (
        v, r.contract_code, r.underlying_symbol, r.contract_size, r.tick_size, r.tick_value,
        r.quote_currency, r.delivery_month, r.expiry_date, r.first_notice_date, r.last_trading_date,
        r.settlement_type, r.exchange_code
      )
      ON CONFLICT (instrument_vid) DO UPDATE
        SET contract_code     = r.contract_code,
            underlying_symbol = r.underlying_symbol,
            contract_size     = r.contract_size,
            tick_size         = r.tick_size,
            tick_value        = r.tick_value,
            quote_currency    = r.quote_currency,
            delivery_month    = r.delivery_month,
            expiry_date       = r.expiry_date,
            first_notice_date = r.first_notice_date,
            last_trading_date = r.last_trading_date,
            settlement_type   = r.settlement_type,
            exchange_code     = r.exchange_code,
            updated_at        = now();
      c := c + 1;
    END IF;
  END LOOP;

  DELETE FROM stg.instrument_futures;
  RETURN c;
END $$;

CREATE OR REPLACE FUNCTION ibor.load_instrument_options_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD; v BIGINT;
BEGIN
  FOR r IN SELECT * FROM stg.instrument_options LOOP
    SELECT instrument_vid INTO v
    FROM ibor.dim_instrument
    WHERE instrument_code = r.instrument_code
      AND is_current = TRUE
    ORDER BY valid_from DESC LIMIT 1;

    IF v IS NOT NULL THEN
      INSERT INTO ibor.dim_instrument_options(
        instrument_vid, option_symbol, underlying_symbol, option_type, strike_price, expiry_date,
        multiplier, premium_currency, exercise_style, settlement_type, exchange_code
      )
      VALUES (
        v, r.option_symbol, r.underlying_symbol, r.option_type, r.strike_price, r.expiry_date,
        r.multiplier, r.premium_currency, r.exercise_style, r.settlement_type, r.exchange_code
      )
      ON CONFLICT (instrument_vid) DO UPDATE
        SET option_symbol     = r.option_symbol,
            underlying_symbol = r.underlying_symbol,
            option_type       = r.option_type,
            strike_price      = r.strike_price,
            expiry_date       = r.expiry_date,
            multiplier        = r.multiplier,
            premium_currency  = r.premium_currency,
            exercise_style    = r.exercise_style,
            settlement_type   = r.settlement_type,
            exchange_code     = r.exchange_code,
            updated_at        = now();
      c := c + 1;
    END IF;
  END LOOP;

  DELETE FROM stg.instrument_options;
  RETURN c;
END $$;

-- =========================
-- Bridges (SCD2)
-- =========================
CREATE OR REPLACE FUNCTION ibor.load_portfolio_strategy_scd2()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD; v_port BIGINT; v_strat BIGINT;
BEGIN
  FOR r IN
    SELECT portfolio_code, strategy_code,
           COALESCE(valid_from, CURRENT_DATE) vf,
           COALESCE(valid_to, DATE '9999-12-31') vt
    FROM stg.portfolio_strategy
  LOOP
    SELECT portfolio_vid INTO v_port
      FROM ibor.dim_portfolio
      WHERE portfolio_code = r.portfolio_code
        AND valid_from <= r.vf AND valid_to >= r.vf
      ORDER BY valid_from DESC LIMIT 1;

    SELECT strategy_vid INTO v_strat
      FROM ibor.dim_strategy
      WHERE strategy_code = r.strategy_code;

    IF v_port IS NULL OR v_strat IS NULL THEN CONTINUE; END IF;

    UPDATE ibor.dim_portfolio_strategy
      SET valid_to = r.vf - 1, is_current = FALSE, updated_at = now()
      WHERE portfolio_vid = v_port AND is_current = TRUE AND valid_from < r.vf;

    INSERT INTO ibor.dim_portfolio_strategy(portfolio_vid, strategy_vid, valid_from, valid_to, is_current)
    VALUES (v_port, v_strat, r.vf, r.vt, (r.vt = DATE '9999-12-31'))
    ON CONFLICT (portfolio_vid, valid_from) DO NOTHING;

    c := c + 1;
  END LOOP;

  DELETE FROM stg.portfolio_strategy;
  RETURN c;
END $$;

CREATE OR REPLACE FUNCTION ibor.load_account_portfolio_scd2()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT := 0; r RECORD; v_port BIGINT; v_acct BIGINT;
BEGIN
  FOR r IN
    SELECT account_code, portfolio_code,
           COALESCE(valid_from, CURRENT_DATE) vf,
           COALESCE(valid_to, DATE '9999-12-31') vt
    FROM stg.account_portfolio
  LOOP
    SELECT account_vid INTO v_acct
      FROM ibor.dim_account
      WHERE account_code = r.account_code
        AND valid_from <= r.vf AND valid_to >= r.vf
      ORDER BY valid_from DESC LIMIT 1;

    SELECT portfolio_vid INTO v_port
      FROM ibor.dim_portfolio
      WHERE portfolio_code = r.portfolio_code
        AND valid_from <= r.vf AND valid_to >= r.vf
      ORDER BY valid_from DESC LIMIT 1;

    IF v_port IS NULL OR v_acct IS NULL THEN CONTINUE; END IF;

    UPDATE ibor.dim_account_portfolio
      SET valid_to = r.vf - 1, is_current = FALSE, updated_at = now()
      WHERE account_vid = v_acct AND is_current = TRUE AND valid_from < r.vf;

    INSERT INTO ibor.dim_account_portfolio(account_vid, portfolio_vid, valid_from, valid_to, is_current)
    VALUES (v_acct, v_port, r.vf, r.vt, (r.vt = DATE '9999-12-31'))
    ON CONFLICT (account_vid, valid_from) DO NOTHING;

    c := c + 1;
  END LOOP;

  DELETE FROM stg.account_portfolio;
  RETURN c;
END $$;

-- =========================
-- Facts
-- =========================
CREATE OR REPLACE FUNCTION ibor.load_fx_rate_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH up AS (
    INSERT INTO ibor.fact_fx_rate(currency_code, rate_date, rate)
    SELECT currency_code, rate_date, rate
    FROM stg.fx_rate
    ON CONFLICT (currency_code, rate_date) DO UPDATE
      SET rate = EXCLUDED.rate,
          updated_at = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;

  DELETE FROM stg.fx_rate;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_price_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH src AS (
    SELECT
      (SELECT instrument_vid FROM ibor.dim_instrument
         WHERE instrument_code = s.instrument_code AND is_current = TRUE
         ORDER BY valid_from DESC LIMIT 1) AS instrument_vid,
      (SELECT price_source_vid FROM ibor.dim_price_source
         WHERE price_source_code = s.price_source_code) AS price_source_vid,
      s.price_ts, s.price_type, s.price, s.currency_code,
      COALESCE(s.is_eod_flag,FALSE) AS is_eod_flag
    FROM stg.price s
  ),
  up AS (
    INSERT INTO ibor.fact_price(instrument_vid, price_source_vid, price_ts, price_type, price, currency_code, is_eod_flag)
    SELECT instrument_vid, price_source_vid, price_ts, price_type, price, currency_code, is_eod_flag
    FROM src
    WHERE instrument_vid IS NOT NULL AND price_source_vid IS NOT NULL
    ON CONFLICT (instrument_vid, price_source_vid, price_ts) DO UPDATE
      SET price        = EXCLUDED.price,
          price_type   = EXCLUDED.price_type,
          currency_code= EXCLUDED.currency_code,
          is_eod_flag  = EXCLUDED.is_eod_flag,
          updated_at   = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;

  DELETE FROM stg.price;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_trade_append()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH src AS (
    SELECT
      s.execution_id, s.trade_code, s.trade_date,
      s.quantity, s.price, s.gross_amount, s.net_amount,
      s.broker_code, s.counterparty_code,
      ibor.fn_account_vid_at(s.account_code,   s.trade_date)    AS account_vid,
      ibor.fn_instrument_vid_at(s.instrument_code, s.trade_date) AS instrument_vid
    FROM stg.trade_fill s
  ),
  up AS (
    INSERT INTO ibor.fact_trade(
      execution_id, trade_code, account_vid, instrument_vid,
      trade_date, quantity, price, gross_amount, net_amount, broker_code, counterparty_code
    )
    SELECT
      execution_id, trade_code, account_vid, instrument_vid,
      trade_date, quantity, price, gross_amount, net_amount, broker_code, counterparty_code
    FROM src
    WHERE account_vid IS NOT NULL AND instrument_vid IS NOT NULL
    ON CONFLICT (execution_id) DO NOTHING
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;

  DELETE FROM stg.trade_fill;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_position_snapshot_upsert()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH src AS (
    SELECT
      ibor.fn_portfolio_vid_at(s.portfolio_code, s.position_date)  AS portfolio_vid,
      ibor.fn_instrument_vid_at(s.instrument_code, s.position_date) AS instrument_vid,
      s.position_date, s.quantity
    FROM stg.position_snapshot s
  ),
  up AS (
    INSERT INTO ibor.fact_position_snapshot(portfolio_vid, instrument_vid, position_date, quantity)
    SELECT portfolio_vid, instrument_vid, position_date, quantity
    FROM src
    WHERE portfolio_vid IS NOT NULL AND instrument_vid IS NOT NULL
    ON CONFLICT (portfolio_vid, instrument_vid, position_date) DO UPDATE
      SET quantity   = EXCLUDED.quantity,
          updated_at = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;

  DELETE FROM stg.position_snapshot;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_cash_event_append()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH src AS (
    SELECT
      ibor.fn_portfolio_vid_at(s.portfolio_code, s.event_date) AS portfolio_vid,
      s.event_date, s.amount, s.currency_code, s.event_type, s.notes
    FROM stg.cash_event s
  ),
  up AS (
    INSERT INTO ibor.fact_cash_event(portfolio_vid, event_date, amount, currency_code, event_type, notes)
    SELECT portfolio_vid, event_date, amount, currency_code, event_type, notes
    FROM src
    WHERE portfolio_vid IS NOT NULL
    ON CONFLICT (portfolio_vid, event_date, amount) DO UPDATE
      SET currency_code = EXCLUDED.currency_code,
          event_type    = EXCLUDED.event_type,
          notes         = EXCLUDED.notes,
          updated_at    = now()
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;

  DELETE FROM stg.cash_event;
  RETURN COALESCE(c,0);
END $$;

CREATE OR REPLACE FUNCTION ibor.load_position_adjustment_append()
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE c BIGINT;
BEGIN
  WITH src AS (
    SELECT
      ibor.fn_portfolio_vid_at(s.portfolio_code, s.effective_date)  AS portfolio_vid,
      ibor.fn_instrument_vid_at(s.instrument_code, s.effective_date) AS instrument_vid,
      s.effective_date, s.quantity_delta, s.reason
    FROM stg.position_adjustment s
  ),
  up AS (
    INSERT INTO ibor.fact_position_adjustment(
      portfolio_vid, instrument_vid, effective_date, quantity_delta, reason
    )
    SELECT portfolio_vid, instrument_vid, effective_date, quantity_delta, reason
    FROM src
    WHERE portfolio_vid IS NOT NULL AND instrument_vid IS NOT NULL
    ON CONFLICT ON CONSTRAINT uq_pos_adj_natural DO NOTHING
    RETURNING 1
  ) SELECT COUNT(*) INTO c FROM up;

  DELETE FROM stg.position_adjustment;
  RETURN COALESCE(c,0);
END $$;

-- =========================
-- Convenience runner
-- =========================
CREATE OR REPLACE FUNCTION ibor.run_all_loaders()
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  PERFORM ibor.load_currency_upsert();
  PERFORM ibor.load_exchange_upsert();
  PERFORM ibor.load_price_source_upsert();
  PERFORM ibor.load_strategy_upsert();

  PERFORM ibor.load_portfolio_scd2();
  PERFORM ibor.load_account_scd2();
  PERFORM ibor.load_instrument_scd2();

  PERFORM ibor.load_instrument_equity_upsert();
  PERFORM ibor.load_instrument_bond_upsert();
  PERFORM ibor.load_instrument_futures_upsert();
  PERFORM ibor.load_instrument_options_upsert();

  PERFORM ibor.load_portfolio_strategy_scd2();
  PERFORM ibor.load_account_portfolio_scd2();

  PERFORM ibor.load_fx_rate_upsert();
  PERFORM ibor.load_price_upsert();
  PERFORM ibor.load_trade_append();
  PERFORM ibor.load_position_snapshot_upsert();
  PERFORM ibor.load_cash_event_append();
  PERFORM ibor.load_position_adjustment_append();
END $$;
