-- Purpose: Automatically manage created_at and updated_at across IBOR and STAGING schemas
-- Enhancement: Always set created_at and updated_at on INSERT (override caller values)

\set ON_ERROR_STOP 1
SET client_min_messages = warning;

-- Ensure schemas exist (safe no-op)
CREATE SCHEMA IF NOT EXISTS ibor;
CREATE SCHEMA IF NOT EXISTS stg;

-- ============================================================
-- - Sets created_at on INSERT (if NULL/missing)
-- - Sets updated_at on INSERT/UPDATE
-- - Applies to all base tables in schemas: ibor, stg
--   (only when the table has created_at AND updated_at columns)
-- ============================================================

-- 1) Create/replace a single audit function
CREATE OR REPLACE FUNCTION ibor.trg_set_audit_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- If caller didn't supply created_at/updated_at, set them
    IF NEW.created_at IS NULL THEN
      NEW.created_at := now();
    END IF;
    IF NEW.updated_at IS NULL THEN
      NEW.updated_at := NEW.created_at;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

-- 2) (Re)apply triggers to all tables in ibor, stg that have the two columns
DO $$
DECLARE
  r RECORD;
  trg_name TEXT;
BEGIN
  FOR r IN
    SELECT t.table_schema, t.table_name
    FROM information_schema.tables t
    WHERE t.table_type = 'BASE TABLE'
      AND t.table_schema IN ('ibor','stg')
      AND EXISTS (
        SELECT 1 FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name   = t.table_name
          AND c.column_name  = 'created_at'
      )
      AND EXISTS (
        SELECT 1 FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name   = t.table_name
          AND c.column_name  = 'updated_at'
      )
  LOOP
    trg_name := format('trg_audit_%I', r.table_name);

    -- Drop previous trigger if present
    EXECUTE format(
      'DROP TRIGGER IF EXISTS %I ON %I.%I;',
      trg_name, r.table_schema, r.table_name
    );

    -- Create BEFORE INSERT OR UPDATE trigger using our audit function
    EXECUTE format(
      'CREATE TRIGGER %I
         BEFORE INSERT OR UPDATE ON %I.%I
         FOR EACH ROW
         EXECUTE FUNCTION ibor.trg_set_audit_columns();',
      trg_name, r.table_schema, r.table_name
    );
  END LOOP;
END
$$;

-- Optional: quick visibility into where triggers were applied
-- SELECT table_schema, table_name
-- FROM information_schema.tables
-- WHERE table_schema IN ('ibor','stg')
-- ORDER BY table_schema, table_name;

