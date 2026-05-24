-- 99_testing_grants.sql
-- Purpose: Grant permissions needed for running tests
--
-- IMPORTANT: This script must be run by a superuser (e.g., via Supabase dashboard SQL editor,
-- or direct connection as the actual postgres superuser)
--
-- These grants allow the postgres role (used for testing) to:
-- 1. Insert/Update/Delete test data in core tables
-- 2. Insert/Update/Delete test data in platform tables
-- 3. Bypass RLS for test setup and teardown

-- ========================================
-- GRANTS FOR CORE SCHEMA
-- ========================================
GRANT ALL ON ALL TABLES IN SCHEMA core TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA core TO postgres;
GRANT USAGE ON SCHEMA core TO postgres;

-- ========================================
-- GRANTS FOR PLATFORM SCHEMA
-- ========================================
GRANT ALL ON ALL TABLES IN SCHEMA platform TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA platform TO postgres;
GRANT USAGE ON SCHEMA platform TO postgres;

-- Include Service Role
GRANT USAGE ON SCHEMA platform TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA platform TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA platform TO service_role;


-- ========================================
-- GRANTS FOR AUTH SCHEMA (for test user creation)
-- ========================================
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO postgres;
GRANT USAGE ON SCHEMA auth TO postgres;

-- ========================================
-- GRANTS FOR TEST_HELPERS SCHEMA
-- ========================================
GRANT ALL ON SCHEMA test_helpers TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test_helpers TO postgres;

-- ========================================
-- BYPASS RLS FOR POSTGRES ROLE
-- ========================================
-- This allows the postgres role to bypass RLS when running tests
ALTER ROLE postgres BYPASSRLS;

-- ========================================
-- DEFAULT PRIVILEGES FOR FUTURE TABLES
-- ========================================
-- Ensure future tables also get the grants
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO postgres;


