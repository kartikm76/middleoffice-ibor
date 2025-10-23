-- Curated, read-only view over instruments + subtype attrs.
-- No JSONB, no description; uses instrument_name as the display/name.

CREATE OR REPLACE VIEW ibor.vw_instrument AS
WITH base AS (
    SELECT
        di.instrument_vid,
        di.instrument_code,
        di.instrument_type,        -- 'EQUITY','BOND','FUT','OPT','FX','INDEX','OTHER'
        di.instrument_name,        -- acts as description/display name
        di.exchange_code,
        di.currency_code,
        di.valid_from,
        di.valid_to
    FROM ibor.dim_instrument di
),

     bd AS (
         SELECT
             b.instrument_vid,
             b.maturity_date,
             b.coupon_rate
         FROM ibor.dim_instrument_bond b
     ),

     fu AS (
         SELECT
             f.instrument_vid,
             f.expiry_date    AS futures_expiry_date,
             f.contract_size
         FROM ibor.dim_instrument_futures f
     ),

     op AS (
         SELECT
             o.instrument_vid,
             o.expiry_date    AS option_expiry_date,
             o.strike_price,
             o.option_type,
             o.multiplier,
             o.underlying_symbol
         FROM ibor.dim_instrument_options o
     )

SELECT
    b.instrument_vid,
    b.instrument_code,
    b.instrument_type,
    b.instrument_name,
    b.exchange_code,
    b.currency_code,
    b.valid_from,
    b.valid_to,
    -- Bond fields (NULL for non-bonds)
    bd.maturity_date,
    bd.coupon_rate,
    -- Futures fields (NULL for non-futures)
    fu.futures_expiry_date,
    fu.contract_size,
    -- Options fields (NULL for non-options)
    op.option_expiry_date,
    op.strike_price,
    op.option_type,
    op.multiplier,
    op.underlying_symbol
FROM base b
         LEFT JOIN bd  ON bd.instrument_vid = b.instrument_vid
         LEFT JOIN fu  ON fu.instrument_vid = b.instrument_vid
         LEFT JOIN op  ON op.instrument_vid = b.instrument_vid;