-- grants.sql
-- Purpose: Grant table-level permissions to authenticated users
-- Note: RLS policies control which rows they can access; these grants control table access

-- ========================================
-- CORE TABLE PERMISSIONS
-- ========================================
-- Grant INSERT/UPDATE on core tables that authenticated users can modify
-- RLS policies control which specific rows they can actually access

GRANT SELECT, INSERT, UPDATE ON core.organizations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.organizations_meta TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.units TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.unit_meta TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.unit_memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.users_meta TO authenticated;
GRANT SELECT, INSERT ON core.audit_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.invitations TO authenticated;
GRANT SELECT ON core.roles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.organization_files TO authenticated;

-- ========================================
-- SERVICE ROLE PERMISSIONS
-- ========================================
-- service_role has full DML on core tables for migrations, seed scripts, and
-- admin backend operations. postgres inherits these via role membership.
-- RLS does not apply to service_role (rolbypassrls = true).
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO service_role;

-- ========================================
-- SEQUENCE PERMISSIONS
-- ========================================
-- Grant sequence usage for inserts (needed for auto-generated IDs)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO service_role;
