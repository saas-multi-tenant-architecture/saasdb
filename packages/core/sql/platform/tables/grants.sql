-- grants.sql
-- Purpose: Reinforce the platform schema lockdown against app_user/PUBLIC,
-- and grant app_admin full access for server-side admin and migrations.
--
-- Platform tables are also locked down upstream by init/schemas.sql:
--   REVOKE ALL ON SCHEMA platform FROM app_user, public;
--   REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM app_user, public;
--
-- All platform access flows through SECURITY DEFINER functions in
-- packages/core/sql/platform/functions/*.sql, which call platform.ensure_platform_user()
-- or platform.ensure_platform_admin() for authorization.
--
-- App users should never have direct privileges on platform.* tables.
-- Earlier broad GRANTs in this file contradicted the schema-level lockdown and
-- exposed platform tables to GraphQL introspection (where pg_graphql is enabled).

-- Defensive re-revoke in case any prior grants remain in a deployed environment.
REVOKE ALL ON SCHEMA platform FROM app_user, PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM app_user, PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA platform FROM app_user, PUBLIC;

-- Cancel any default-privilege grants that future tables would otherwise inherit.
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON TABLES FROM app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON SEQUENCES FROM app_user;

-- app_admin (the backend/admin role) retains full access to
-- platform.* so server-side jobs, migrations, and test harnesses can manage
-- platform state directly. app_admin also has BYPASSRLS, so RLS policies
-- on platform tables do not apply to it.
GRANT USAGE ON SCHEMA platform TO app_admin;
GRANT ALL ON ALL TABLES IN SCHEMA platform TO app_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA platform TO app_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON TABLES TO app_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON SEQUENCES TO app_admin;
