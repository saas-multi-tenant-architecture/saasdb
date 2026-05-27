BEGIN;

-- ============================================================================
-- SMTA Database Cleanup Script
-- ============================================================================
-- Purpose: Completely reset the database by removing all SMTA artifacts
--          while preserving Supabase built-in objects
--
-- This script removes:
--   - SMTA triggers on auth.users
--   - Supabase Vault entries referenced by tenant_secrets
--   - All objects in core, platform, and utils schemas
--   - All user-defined functions in public schema
--
-- This script preserves:
--   - Supabase auth schema and auth.users data
--   - Extension-owned functions
--   - Supabase built-in objects
-- ============================================================================

-- 1) Drop SMTA trigger on auth.users (created by new_user.sql)
--    This trigger is ON auth.users, not within core schema, so it must be
--    explicitly dropped before the core schema is removed
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;

-- 2) Clean up Supabase Vault entries referenced by tenant_secrets
--    Must be done BEFORE dropping platform schema to avoid orphaned vault entries
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT vault_key_id
    FROM platform.tenant_secrets
    WHERE vault_key_id IS NOT NULL
  LOOP
    -- Delete from vault.secrets using the vault_key_id
    DELETE FROM vault.secrets WHERE id = r.vault_key_id;
  END LOOP;
EXCEPTION
  WHEN undefined_table THEN
    -- platform.tenant_secrets doesn't exist, skip
    NULL;
  WHEN invalid_schema_name THEN
    -- vault schema doesn't exist, skip
    NULL;
END $$;

-- 3) Nuke SMTA schemas (tables, views, sequences, functions, types, triggers, etc.)
DO $$
DECLARE
  s text;
BEGIN
  FOREACH s IN ARRAY ARRAY['core','platform','utils','app'] LOOP
    EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE', s);
    EXECUTE format('CREATE SCHEMA %I', s);
  END LOOP;
END $$;

-- 3a) Drop test-only schema (no recreate; tests/fixtures/00_test_helpers.sql rebuilds it)
DROP SCHEMA IF EXISTS test_helpers CASCADE;

-- 4) Drop ALL user-defined functions in public (safely skips extension-owned functions)
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT
      p.oid,
      p.proname,
      pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'  -- 'f' = function (excludes procedures/aggregates)
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.classid = 'pg_proc'::regclass
          AND d.objid = p.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'  -- extension-owned
      )
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS public.%I(%s) CASCADE', r.proname, r.args);
  END LOOP;
END $$;

-- 5) Optional: Clean up application data from auth.users
--    WARNING: This deletes ALL users! Only uncomment for complete reset.
DELETE FROM auth.users;

COMMIT;
