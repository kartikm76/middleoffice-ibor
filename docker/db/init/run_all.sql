\set ON_ERROR_STOP 1

-- 1) Curated schema (drops/recreates ibor)
\i docker/db/init/01_main_schema.sql

-- 2) Staging schema (drops/recreates stg)
\i docker/db/init/02_staging_schema.sql

-- 3) Audit triggers
\i docker/db/init/03_audit_trigger.sql

-- 4) Helpers (PIT/resolvers/FX/price)
\i docker/db/init/05_helpers.sql

-- 5) Loaders (SCD2 + facts)
\i docker/db/init/04_loaders.sql
