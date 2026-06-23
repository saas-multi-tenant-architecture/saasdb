-- grants.sql
-- Purpose: Grant table-level permissions to app_user and app_admin roles
-- Note: RLS policies control which rows they can access; these grants control table access

-- ========================================
-- CORE TABLE PERMISSIONS
-- ========================================
-- Grant INSERT/UPDATE on core tables that app_user can modify
-- RLS policies control which specific rows they can actually access

GRANT SELECT, INSERT, UPDATE ON core.organizations TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.organizations_meta TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.units TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.unit_meta TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.memberships TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.unit_memberships TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.users_meta TO app_user;
GRANT SELECT, INSERT ON core.audit_logs TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.invitations TO app_user;
GRANT SELECT ON core.roles TO app_user;
GRANT SELECT, INSERT, UPDATE ON core.organization_files TO app_user;

-- ========================================
-- ADMIN ROLE PERMISSIONS
-- ========================================
-- app_admin has full DML on core tables for migrations, seed scripts, and
-- admin backend operations. app_admin has BYPASSRLS, so RLS does not apply to it.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO app_admin;

-- ========================================
-- SEQUENCE PERMISSIONS
-- ========================================
-- Grant sequence usage for inserts (needed for auto-generated IDs)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO app_admin;
