-- 00b_plain_pg_shim.sql
-- Purpose: Override the Supabase-specific test_helpers.* functions with plain
-- Postgres equivalents (auth-user setter using app.current_user_id only, no
-- GoTrue 'role'; better-auth "user" table instead of auth.users; etc.).
--
-- Prerequisites (the "user" table and the authenticated/anon/service_role role
-- aliases) live in 00a_plain_pg_prereqs.sql, which must load BEFORE
-- 00_test_helpers.sql. This file must load AFTER 00_test_helpers.sql because it
-- grants on and replaces functions in the test_helpers schema that file creates.

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
