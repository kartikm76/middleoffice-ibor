-- =============================================================================
-- #18: Range partitioning for dim_instrument (SCD2 optimization)
--
-- PURPOSE:
--   dim_instrument uses SCD2 (valid_from / valid_to / is_current). Without
--   partitioning, every point-in-time (PIT) lookup scans 100% of history.
--   Partitioning by valid_from year constrains each PIT query to 1-2 partitions.
--
-- WHEN TO APPLY:
--   Run this on a FRESH schema only (before any data is loaded).
--   For existing schemas with data, use the migration approach below.
--
-- NOTE:
--   PostgreSQL declarative partitioning requires the original table to be
--   recreated. The steps below show both approaches.
-- =============================================================================

-- =============================================================================
-- APPROACH A: Fresh schema (drop and recreate as partitioned)
-- Apply INSTEAD of the dim_instrument table in 01_main_schema.sql
-- =============================================================================

/*
-- Drop the non-partitioned version first (fresh schema only)
DROP TABLE IF EXISTS ibor.dim_instrument CASCADE;

CREATE TABLE ibor.dim_instrument (
  instrument_vid    BIGSERIAL,
  instrument_code   TEXT NOT NULL,
  instrument_type   TEXT NOT NULL,
  description       TEXT,
  currency_code     CHAR(3) REFERENCES ibor.dim_currency(currency_code),
  exchange_code     TEXT,
  isin              TEXT,
  sedol             TEXT,
  cusip             TEXT,
  valid_from        DATE NOT NULL,
  valid_to          DATE,
  is_current        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMP NOT NULL DEFAULT now(),
  updated_at        TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (instrument_vid, valid_from)        -- partition key must be in PK
) PARTITION BY RANGE (valid_from);

-- Annual partitions (add more years as needed)
CREATE TABLE ibor.dim_instrument_y2020 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE ibor.dim_instrument_y2021 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE ibor.dim_instrument_y2022 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE ibor.dim_instrument_y2023 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE ibor.dim_instrument_y2024 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE ibor.dim_instrument_y2025 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE ibor.dim_instrument_y2026 PARTITION OF ibor.dim_instrument
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
-- Catch-all for older/future data
CREATE TABLE ibor.dim_instrument_default PARTITION OF ibor.dim_instrument DEFAULT;

-- Indexes on each partition are inherited automatically in PG 11+
CREATE INDEX IF NOT EXISTS idx_instr_code ON ibor.dim_instrument (instrument_code);
CREATE INDEX IF NOT EXISTS idx_instr_pit  ON ibor.dim_instrument (valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_instr_current ON ibor.dim_instrument (instrument_code) WHERE is_current;
*/

-- =============================================================================
-- APPROACH B: Live migration (existing schema with data)
-- Run in a maintenance window; swap is near-instant after data copy.
-- =============================================================================

/*
BEGIN;

-- 1. Create new partitioned table alongside the existing one
CREATE TABLE ibor.dim_instrument_partitioned (
  LIKE ibor.dim_instrument INCLUDING ALL,
  PRIMARY KEY (instrument_vid, valid_from)
) PARTITION BY RANGE (valid_from);

CREATE TABLE ibor.dim_instrument_partitioned_default
  PARTITION OF ibor.dim_instrument_partitioned DEFAULT;

-- 2. Copy all rows
INSERT INTO ibor.dim_instrument_partitioned SELECT * FROM ibor.dim_instrument;

-- 3. Swap names atomically
ALTER TABLE ibor.dim_instrument          RENAME TO dim_instrument_old;
ALTER TABLE ibor.dim_instrument_partitioned RENAME TO dim_instrument;

-- 4. Drop old table after verifying data
-- DROP TABLE ibor.dim_instrument_old CASCADE;

COMMIT;
*/
