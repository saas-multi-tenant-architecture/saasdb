-- 00a_plain_pg_prereqs.sql
-- Purpose: Prerequisites the pgTap suite assumes from Supabase but that do not
-- exist on vanilla Postgres, and that must be present BEFORE 00_test_helpers.sql
-- loads (it grants on these roles). Split out of 00b_plain_pg_shim.sql so the
-- test_helpers schema can be created in between:
--
--   00a_plain_pg_prereqs.sql  <- roles + "user" table   (this file)
--   00_test_helpers.sql       <- creates test_helpers schema + grants to the roles
--   00b_plain_pg_shim.sql     <- overrides test_helpers.* for plain Postgres
--
-- Roles are cluster-global, so on a warm cluster these CREATEs are no-ops; the
-- IF NOT EXISTS guards keep a cold cluster's first run green too.

-- ========================================
-- BETTER-AUTH USER TABLE
-- ========================================
CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT now(),
  "updatedAt" TIMESTAMPTZ DEFAULT now()
);

-- ========================================
-- SUPABASE ROLE ALIASES
-- These roles don't exist on plain Postgres.  We create them and wire them to
-- the equivalent app_user / app_admin roles so that has_function_privilege()
-- and has_table_privilege() return the same answers the tests expect.
-- ========================================

-- authenticated = app_user (the normal authenticated-user runtime role)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END $$;
GRANT app_user TO authenticated;

-- anon = unprivileged public role (no grants needed; tests assert it has NO execute)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END $$;

-- service_role = app_admin (admin / BYPASSRLS role)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
END $$;
GRANT app_admin TO service_role;
