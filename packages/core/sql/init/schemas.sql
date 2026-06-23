-- schemas.sql
-- Purpose: Create all foundational schemas for the project
-- Run this file first before any schema-specific DDL

-- ========================================
-- SCHEMA CREATION
-- ========================================
CREATE SCHEMA IF NOT EXISTS utils;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS platform;

-- ========================================
-- NOTES
-- ========================================
-- These schemas define logical boundaries:
-- - utils: shared triggers/functions
-- - core: identity, access control, helper functions, audit logs
-- - app: tenant-facing application tables
-- - platform: SaaS-wide admin and control layer (service role only)


-- ========================================
-- NEUTRAL APPLICATION ROLES
-- ========================================
-- SMTA core is adapter-agnostic. It owns two neutral roles:
--   app_user  — the runtime identity the application backend assumes.
--               RLS-subject (NOT BYPASSRLS): row access is enforced via
--               core.get_current_user_id() reading app.current_user_id.
--   app_admin — migrations/seed/admin DML. BYPASSRLS.
-- Adapters map their reality onto these (e.g. the supabase adapter grants
-- app_user TO authenticated and app_admin TO service_role).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user')  THEN CREATE ROLE app_user  NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_admin') THEN CREATE ROLE app_admin NOLOGIN BYPASSRLS; END IF;
END $$;

-- ========================================
-- ACCESS CONTROL
-- ========================================
GRANT USAGE ON SCHEMA utils TO app_user;
GRANT USAGE ON SCHEMA core  TO app_user;
GRANT USAGE ON SCHEMA app   TO app_user;

GRANT USAGE ON SCHEMA utils TO app_admin;
GRANT USAGE ON SCHEMA core  TO app_admin;
GRANT USAGE ON SCHEMA app   TO app_admin;

-- ========================================
-- DEFAULT TABLE PRIVILEGES
-- ========================================
-- NOTE: SMTA intentionally does NOT set default privileges on the shared `app`
-- schema (finding C10). The consuming project owns `app` table privileges.
ALTER DEFAULT PRIVILEGES IN SCHEMA utils GRANT SELECT ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA core  GRANT SELECT ON TABLES TO app_user;

-- Lock down platform schema to prevent tenant access.
REVOKE ALL ON SCHEMA platform FROM app_user, PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM app_user, PUBLIC;
