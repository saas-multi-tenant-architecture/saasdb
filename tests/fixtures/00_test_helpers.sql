-- 00_test_helpers.sql
-- Purpose: Helper functions and utilities for pgTap testing

-- ========================================
-- REQUIRED EXTENSIONS
-- ========================================
CREATE EXTENSION IF NOT EXISTS pgtap;
-- Note: uuid-ossp is pre-installed in Supabase under the 'extensions' schema

-- ========================================
-- TEST SCHEMA
-- ========================================
-- Create a schema to hold test-specific helpers and data
CREATE SCHEMA IF NOT EXISTS test_helpers;

-- ========================================
-- FUNCTION: test_helpers.set_auth_user()
-- ========================================
-- Simulate authentication as a specific user for RLS testing
-- This sets the auth.uid() to return the specified user_id
CREATE OR REPLACE FUNCTION test_helpers.set_auth_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- FUNCTION: test_helpers.clear_auth_user()
-- ========================================
-- Clear the simulated authentication
CREATE OR REPLACE FUNCTION test_helpers.clear_auth_user()
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('role', 'anon', true);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- FUNCTION: test_helpers.set_service_role()
-- ========================================
-- Simulate service role for platform operations
CREATE OR REPLACE FUNCTION test_helpers.set_service_role()
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('role', 'service_role', true);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- FUNCTION: test_helpers.create_test_user()
-- ========================================
-- Create a test user in auth.users (simulates Supabase auth)
-- Returns the user's UUID
-- SECURITY DEFINER bypasses RLS to allow test data creation
CREATE OR REPLACE FUNCTION test_helpers.create_test_user(
  p_email TEXT,
  p_first_name TEXT DEFAULT NULL,
  p_last_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Generate a deterministic UUID based on email for reproducibility
  -- Uses the well-known URL namespace UUID
  v_user_id := extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, p_email);

  -- Insert into auth.users (minimal fields needed)
  INSERT INTO auth.users (id, email, email_confirmed_at, created_at, updated_at)
  VALUES (v_user_id, p_email, now(), now(), now())
  ON CONFLICT (id) DO NOTHING;

  -- Upsert users_meta: the trigger populates it on INSERT to auth.users,
  -- but ON CONFLICT DO NOTHING above suppresses the trigger for existing rows.
  -- We upsert directly to handle both the first-run and schema-rebuild cases.
  INSERT INTO core.users_meta (id, email, first_name, last_name)
  VALUES (v_user_id, p_email, p_first_name, p_last_name)
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, auth, public;

-- ========================================
-- FUNCTION: test_helpers.cleanup_test_data()
-- ========================================
-- Remove all test data (call at end of test suite)
-- SECURITY DEFINER bypasses RLS to allow test data cleanup
CREATE OR REPLACE FUNCTION test_helpers.cleanup_test_data()
RETURNS VOID AS $$
BEGIN
  -- Demote super_admin memberships first — the protect_super_admin trigger blocks
  -- direct DELETE on is_super_admin=true rows. The trigger allows the flag to be
  -- cleared to false; after that DELETE proceeds without triggering the guard.
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
  DELETE FROM auth.users WHERE email LIKE '%@test.bellaitalia.com' OR email LIKE '%@test.pizzapalace.com';
  -- Keep roles as they may be needed for future tests
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform, auth, public;

-- ========================================
-- FUNCTION: test_helpers.unit_is_soft_deleted()
-- ========================================
-- Check if a unit is soft-deleted, bypassing RLS
-- SECURITY DEFINER required because RLS hides is_deleted=true rows from authenticated users
CREATE OR REPLACE FUNCTION test_helpers.unit_is_soft_deleted(p_unit_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM core.units
    WHERE id = p_unit_id AND is_deleted = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.membership_is_soft_deleted()
-- ========================================
-- Check if an org membership is soft-deleted, bypassing RLS
-- SECURITY DEFINER required because RLS hides is_deleted=true rows
CREATE OR REPLACE FUNCTION test_helpers.membership_is_soft_deleted(p_user_id UUID, p_org_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = p_user_id
      AND organization_id = p_org_id
      AND is_deleted = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.unit_membership_is_soft_deleted()
-- ========================================
-- Check if a unit membership is soft-deleted, bypassing RLS
-- SECURITY DEFINER required because RLS hides is_deleted=true rows
CREATE OR REPLACE FUNCTION test_helpers.unit_membership_is_soft_deleted(p_user_id UUID, p_unit_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = p_user_id
      AND unit_id = p_unit_id
      AND is_deleted = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.get_test_user_id()
-- ========================================
-- Returns deterministic UUID for a test email (same as create_test_user)
-- Uses the well-known URL namespace UUID: 6ba7b811-9dad-11d1-80b4-00c04fd430c8
CREATE OR REPLACE FUNCTION test_helpers.get_test_user_id(p_email TEXT)
RETURNS UUID AS $$
BEGIN
  RETURN extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, p_email);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ========================================
-- FUNCTION: test_helpers.seed_organization()
-- ========================================
-- Insert an organization (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_organization(
  p_id UUID,
  p_name TEXT,
  p_description TEXT,
  p_created_by UUID
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.organizations (id, name, description, created_by)
  VALUES (p_id, p_name, p_description, p_created_by)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.seed_membership()
-- ========================================
-- Insert a membership (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_membership(
  p_user_id UUID,
  p_organization_id UUID,
  p_role_id UUID,
  p_is_super_admin BOOLEAN DEFAULT FALSE,
  p_created_by UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by)
  VALUES (p_user_id, p_organization_id, p_role_id, p_is_super_admin, p_created_by)
  ON CONFLICT (user_id, organization_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.seed_unit()
-- ========================================
-- Insert a unit (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_unit(
  p_id UUID,
  p_organization_id UUID,
  p_name TEXT,
  p_description TEXT,
  p_created_by UUID
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
  VALUES (p_id, p_organization_id, p_name, p_description, p_created_by, p_created_by)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.seed_unit_membership()
-- ========================================
-- Insert a unit membership (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_unit_membership(
  p_user_id UUID,
  p_unit_id UUID,
  p_role_id UUID,
  p_created_by UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (p_user_id, p_unit_id, p_role_id, p_created_by)
  ON CONFLICT (user_id, unit_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.seed_audit_log()
-- ========================================
-- Insert an audit log entry (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_audit_log(
  p_actor_id UUID,
  p_organization_id UUID,
  p_target_table TEXT,
  p_target_id UUID,
  p_action TEXT,
  p_summary TEXT
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.audit_logs (actor_id, organization_id, target_table, target_id, action, summary)
  VALUES (p_actor_id, p_organization_id, p_target_table, p_target_id, p_action, p_summary);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.seed_role()
-- ========================================
-- Insert or update a role (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_role(
  p_id UUID,
  p_name TEXT,
  p_description TEXT,
  p_casl_rules JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.roles (id, name, description, casl_rules, created_at, updated_at)
  VALUES (p_id, p_name, p_description, p_casl_rules, now(), now())
  ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    casl_rules = EXCLUDED.casl_rules,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, public;

-- ========================================
-- FUNCTION: test_helpers.seed_platform_role()
-- ========================================
-- Insert a platform role (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_platform_role(
  p_id UUID,
  p_name TEXT,
  p_description TEXT,
  p_casl_rules JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_roles (id, name, description, casl_rules)
  VALUES (p_id, p_name, p_description, p_casl_rules)
  ON CONFLICT (name) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_platform_user()
-- ========================================
-- Insert a platform user (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_platform_user(
  p_id UUID,
  p_supabase_user_id UUID,
  p_email TEXT,
  p_role_id UUID
) RETURNS VOID AS $$
BEGIN
  -- Column renamed core-wide to user_id (was supabase_user_id); the p_supabase_user_id
  -- param name is retained for positional call-site + override-signature compatibility.
  INSERT INTO platform.platform_users (id, user_id, email, role_id)
  VALUES (p_id, p_supabase_user_id, p_email, p_role_id)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_platform_setting()
-- ========================================
-- Insert a platform setting (bypasses RLS)
-- Note: value is JSONB type
CREATE OR REPLACE FUNCTION test_helpers.seed_platform_setting(
  p_key TEXT,
  p_value JSONB,
  p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_settings (key, value, description)
  VALUES (p_key, p_value, p_description)
  ON CONFLICT (key) DO UPDATE SET
    value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_feature_flag()
-- ========================================
-- Insert a feature flag (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_feature_flag(
  p_id UUID,
  p_key TEXT,
  p_value JSONB,
  p_is_active BOOLEAN DEFAULT TRUE,
  p_organization_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_feature_flags (id, key, value, is_active, organization_id, description)
  VALUES (p_id, p_key, p_value, p_is_active, p_organization_id, p_description)
  ON CONFLICT (id) DO UPDATE SET
    value = EXCLUDED.value,
    is_active = EXCLUDED.is_active,
    description = EXCLUDED.description,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_platform_organization()
-- ========================================
-- Insert a platform organization (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_platform_organization(
  p_id UUID,
  p_label TEXT,
  p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_organizations (id, label, notes)
  VALUES (p_id, p_label, p_notes)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_billing_customer()
-- ========================================
-- Insert a billing customer (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_billing_customer(
  p_organization_id UUID,
  p_provider_customer_id TEXT,
  p_billing_email TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.billing_customers (organization_id, provider_customer_id, billing_email)
  VALUES (p_organization_id, p_provider_customer_id, p_billing_email)
  ON CONFLICT (organization_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_subscription_product()
-- ========================================
-- Insert a subscription product (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_subscription_product(
  p_id UUID,
  p_paymentprocessor_price_id TEXT,
  p_name TEXT,
  p_description TEXT,
  p_billing_interval TEXT,
  p_amount INTEGER
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.subscription_products (id, paymentprocessor_price_id, name, description, billing_interval, amount)
  VALUES (p_id, p_paymentprocessor_price_id, p_name, p_description, p_billing_interval, p_amount)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- FUNCTION: test_helpers.seed_billing_subscription()
-- ========================================
-- Insert a billing subscription (bypasses RLS)
CREATE OR REPLACE FUNCTION test_helpers.seed_billing_subscription(
  p_id UUID,
  p_organization_id UUID,
  p_provider_subscription_id TEXT,
  p_plan TEXT,
  p_status TEXT
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.billing_subscriptions (id, organization_id, provider_subscription_id, plan, status)
  VALUES (p_id, p_organization_id, p_provider_subscription_id, p_plan, p_status)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform, public;

-- ========================================
-- GRANTS
-- ========================================
-- Tests call test_helpers functions after set_auth_user() switches to
-- the 'authenticated' role. Without these grants the calls fail with
-- "permission denied for schema test_helpers".
GRANT USAGE ON SCHEMA test_helpers TO authenticated, anon, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_helpers TO authenticated, anon, service_role;

-- ========================================
-- NOTES
-- ========================================
-- These helpers assume:
-- 1. pgTap extension is available
-- 2. auth.uid() function checks request.jwt.claim.sub
-- 3. Tests run in a transaction that gets rolled back
-- 4. SECURITY DEFINER functions run as owner (postgres) bypassing RLS
