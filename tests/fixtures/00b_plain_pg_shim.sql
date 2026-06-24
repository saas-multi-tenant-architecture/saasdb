-- 00b_plain_pg_shim.sql
-- Purpose: Provide, on vanilla Postgres, the environment pieces the pgTap suite
-- assumed from Supabase: a Better-Auth-style "user" table and an auth-user setter
-- that uses app.current_user_id only (no GoTrue 'role').
--
-- Also creates Supabase role aliases (authenticated, anon, service_role) so that
-- privilege-check tests (has_function_privilege / has_table_privilege) pass on
-- plain Postgres where those roles do not exist out of the box.

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

-- Grant EXECUTE on test_helpers functions to all three aliases so tests that
-- call set_auth_user / get_test_user_id under these roles don't fail.
GRANT USAGE ON SCHEMA test_helpers TO authenticated, anon, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_helpers TO authenticated, anon, service_role;

-- ========================================
-- OVERRIDE: test_helpers.set_auth_user
-- Sets app.current_user_id (used by core.get_current_user_id() and RLS policies)
-- and switches the session role to 'authenticated' so RLS is enforced.
-- The 'authenticated' role created above inherits app_user and is subject to RLS.
-- ========================================
CREATE OR REPLACE FUNCTION test_helpers.set_auth_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- OVERRIDE: test_helpers.create_test_user
-- Inserts into the better-auth "user" table instead of auth.users and uses
-- gen_random_uuid() instead of extensions.uuid_generate_v5().
-- ========================================
CREATE OR REPLACE FUNCTION test_helpers.create_test_user(
  p_email TEXT, p_first_name TEXT DEFAULT NULL, p_last_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Check if a user with this email already exists (idempotent across fixture reloads)
  SELECT id INTO v_user_id FROM core.users_meta WHERE email = p_email LIMIT 1;
  IF v_user_id IS NOT NULL THEN
    RETURN v_user_id;
  END IF;

  v_user_id := gen_random_uuid();
  INSERT INTO "user" (id, email, name) VALUES (v_user_id::text, p_email, p_first_name)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO core.users_meta (id, email, first_name, last_name)
  VALUES (v_user_id, p_email, p_first_name, p_last_name)
  ON CONFLICT (id) DO NOTHING;
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- OVERRIDE: test_helpers.get_test_user_id
-- On Supabase this derives a deterministic UUID from the email via
-- extensions.uuid_generate_v5() — unavailable on plain Postgres.
-- On plain Postgres we look up the UUID stored by create_test_user().
-- ========================================
CREATE OR REPLACE FUNCTION test_helpers.get_test_user_id(p_email TEXT)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  SELECT id INTO v_id FROM core.users_meta WHERE email = p_email LIMIT 1;
  RETURN v_id;  -- returns NULL if user not yet created (same semantics as a missed lookup)
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- OVERRIDE: test_helpers.cleanup_test_data
-- Removes the auth.users DELETE (no auth schema on plain Postgres) and adds
-- cleanup of the better-auth "user" table.
-- ========================================
CREATE OR REPLACE FUNCTION test_helpers.cleanup_test_data()
RETURNS VOID AS $$
BEGIN
  -- Demote super_admin memberships first — the protect_super_admin trigger blocks
  -- direct DELETE on is_super_admin=true rows.
  UPDATE core.memberships SET is_super_admin = false WHERE is_super_admin = true AND is_deleted = false;
  -- Delete in reverse dependency order
  DELETE FROM core.unit_memberships;
  DELETE FROM core.unit_meta;
  DELETE FROM core.units;
  DELETE FROM core.memberships;
  DELETE FROM core.organizations_meta;
  DELETE FROM core.organization_files;
  DELETE FROM core.audit_logs;
  DELETE FROM platform.platform_organizations;
  DELETE FROM core.organizations;
  DELETE FROM core.users_meta;
  -- Clean up the better-auth user table (replaces auth.users on plain Postgres)
  DELETE FROM "user"
  WHERE email LIKE '%@test.bellaitalia.com'
     OR email LIKE '%@test.pizzapalace.com'
     OR email LIKE '%@pizzatech-saas.com'
     OR email LIKE '%@test.com';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform, public;

-- ========================================
-- OVERRIDE: test_helpers.seed_platform_user
-- On Supabase platform_users has a supabase_user_id column.
-- The better-auth schema uses user_id instead.
-- ========================================
CREATE OR REPLACE FUNCTION test_helpers.seed_platform_user(
  p_id UUID,
  p_supabase_user_id UUID,   -- kept for call-site compatibility; mapped to user_id
  p_email TEXT,
  p_role_id UUID
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_users (id, user_id, email, role_id)
  VALUES (p_id, p_supabase_user_id, p_email, p_role_id)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;
