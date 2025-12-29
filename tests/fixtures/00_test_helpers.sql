-- 00_test_helpers.sql
-- Purpose: Helper functions and utilities for pgTap testing

-- ========================================
-- PGTAP EXTENSION
-- ========================================
CREATE EXTENSION IF NOT EXISTS pgtap;

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
  -- Set the request.jwt.claim.sub to simulate Supabase auth
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  -- Also set role to authenticated
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
CREATE OR REPLACE FUNCTION test_helpers.create_test_user(
  p_email TEXT,
  p_first_name TEXT DEFAULT NULL,
  p_last_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Generate a deterministic UUID based on email for reproducibility
  v_user_id := uuid_generate_v5(uuid_ns_url(), p_email);

  -- Insert into auth.users (minimal fields needed)
  INSERT INTO auth.users (id, email, email_confirmed_at, created_at, updated_at)
  VALUES (v_user_id, p_email, now(), now(), now())
  ON CONFLICT (id) DO NOTHING;

  -- Update users_meta with name (trigger should have created the row)
  UPDATE core.users_meta
  SET first_name = p_first_name,
      last_name = p_last_name,
      email = p_email
  WHERE id = v_user_id;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- FUNCTION: test_helpers.cleanup_test_data()
-- ========================================
-- Remove all test data (call at end of test suite)
CREATE OR REPLACE FUNCTION test_helpers.cleanup_test_data()
RETURNS VOID AS $$
BEGIN
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
$$ LANGUAGE plpgsql;

-- ========================================
-- NOTES
-- ========================================
-- These helpers assume:
-- 1. pgTap extension is available
-- 2. auth.uid() function checks request.jwt.claim.sub
-- 3. Tests run in a transaction that gets rolled back
