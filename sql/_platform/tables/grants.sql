-- grants.sql
-- Purpose: Grant platform schema/table permissions to authenticated users
-- Note: RLS policies control which rows they can access; these grants control base privileges.

-- ========================================
-- PLATFORM SCHEMA PERMISSIONS
-- ========================================
-- Required so authenticated users can reference platform.* objects.
GRANT USAGE ON SCHEMA platform TO authenticated;

-- Allow authenticated to attempt SELECT/INSERT/UPDATE (RLS decides what is allowed).
-- Intentionally do NOT grant DELETE.
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA platform TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA platform TO authenticated;

-- Ensure future platform tables/sequences get the same privileges.
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT SELECT, INSERT, UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT USAGE ON SEQUENCES TO authenticated;
