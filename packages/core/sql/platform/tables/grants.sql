-- grants.sql
-- Purpose: Intentionally empty.
--
-- Platform tables are locked down by init/schemas.sql:
--   REVOKE ALL ON SCHEMA platform FROM authenticated, anon, public;
--   REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, public;
--
-- All platform access flows through SECURITY DEFINER functions in
-- packages/core/sql/platform/functions/*.sql, which call platform.ensure_platform_user()
-- or platform.ensure_platform_admin() for authorization.
--
-- Authenticated users should never have direct privileges on platform.* tables.
-- Earlier broad GRANTs in this file contradicted the schema-level lockdown and
-- exposed platform tables in the pg_graphql schema (Supabase lint 0027).

-- Defensive re-revoke in case any prior grants remain in a deployed environment.
REVOKE ALL ON SCHEMA platform FROM authenticated, anon, PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA platform FROM authenticated, anon, PUBLIC;

-- Cancel any default-privilege grants that future tables would otherwise inherit.
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON TABLES FROM authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON SEQUENCES FROM authenticated;

-- service_role (the Supabase backend/admin role) retains full access to
-- platform.* so server-side jobs, migrations, and test harnesses can manage
-- platform state directly. service_role also has BYPASSRLS, so RLS policies
-- on platform tables do not apply to it.
GRANT USAGE ON SCHEMA platform TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA platform TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA platform TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON SEQUENCES TO service_role;
