-- policies.sql
-- Purpose: Enable RLS and define policies for core tables
--
-- Policy Philosophy:
-- - super_admin (tenant owner) has full CRUD access to all tenant tables
-- - RLS validates membership in org/unit for other users
-- - Fine-grained access control is delegated to CASL (application layer)
-- - This template is permissive by design; developers can restrict via CASL
--
-- Deletion Strategy:
-- - DELETE policies are intentionally NOT defined for core tables
-- - All deletions must be "soft deletes" via UPDATE (setting is_deleted = true)
-- - This ensures data recovery is possible and audit trails are preserved
-- - The protect_super_admin trigger enforces this for super_admin memberships
-- - Hard DELETEs are blocked by default RLS deny-all behavior

-- ========================================
-- RLS ENABLEMENT
-- ========================================
ALTER TABLE core.users_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organization_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.roles ENABLE ROW LEVEL SECURITY;

-- ========================================
-- POLICIES: users_meta
-- ========================================
-- User's own data or shared organization members can view
-- Only the user can update their own record
CREATE POLICY users_meta_select ON core.users_meta
  FOR SELECT USING (
    (SELECT core.get_current_user_id()) = id OR core.shares_organization(id)
  );

CREATE POLICY users_meta_update ON core.users_meta
  FOR UPDATE USING ((SELECT core.get_current_user_id()) = id)
  WITH CHECK ((SELECT core.get_current_user_id()) = id);

-- ========================================
-- POLICIES: organizations_meta
-- ========================================
-- Org members can view and update (CASL controls fine-grained access)
CREATE POLICY organizations_meta_select ON core.organizations_meta
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(id) OR core.is_super_admin(id))
  );

CREATE POLICY organizations_meta_update ON core.organizations_meta
  FOR UPDATE USING (
    is_deleted = false AND core.is_super_admin(id)
  )
  WITH CHECK (
    core.is_super_admin(id)
  );

-- ========================================
-- POLICIES: organizations
-- ========================================
-- Members can read and update, creator can insert
CREATE POLICY organizations_select ON core.organizations
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(id) OR core.is_super_admin(id))
  );

CREATE POLICY organizations_insert ON core.organizations
  FOR INSERT WITH CHECK ((SELECT core.get_current_user_id()) = created_by);

CREATE POLICY organizations_update ON core.organizations
  FOR UPDATE USING (
    is_deleted = false AND core.is_super_admin(id)
  )
  WITH CHECK (
    core.is_super_admin(id)
  );

-- ========================================
-- POLICIES: units
-- ========================================
-- Org members can read/insert/update (CASL controls fine-grained access)
CREATE POLICY units_select ON core.units
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  );

CREATE POLICY units_insert ON core.units
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

CREATE POLICY units_update ON core.units
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  )
  WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: unit_meta
-- ========================================
-- Unit members or org members can read/update (CASL controls fine-grained access)
CREATE POLICY unit_meta_select ON core.unit_meta
  FOR SELECT USING (
    is_deleted = false AND (core.is_unit_member(id) OR core.is_org_member_for_unit(id) OR core.is_org_super_admin_for_unit(id))
  );

CREATE POLICY unit_meta_update ON core.unit_meta
  FOR UPDATE USING (
    is_deleted = false AND (core.is_unit_member(id) OR core.is_org_member_for_unit(id) OR core.is_org_super_admin_for_unit(id))
  )
  WITH CHECK (
    core.is_unit_member(id) OR core.is_org_member_for_unit(id) OR core.is_org_super_admin_for_unit(id)
  );

-- ========================================
-- POLICIES: memberships
-- ========================================
-- Users see their own rows, org members can manage (CASL controls fine-grained access)
-- Note: protect_super_admin trigger prevents deletion of super_admin membership
CREATE POLICY memberships_select ON core.memberships
  FOR SELECT USING (
    is_deleted = false AND ((SELECT core.get_current_user_id()) = user_id OR core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  );

CREATE POLICY memberships_insert ON core.memberships
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

CREATE POLICY memberships_update ON core.memberships
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  )
  WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: unit_memberships
-- ========================================
-- Users see their own rows, org members can manage (CASL controls fine-grained access)
CREATE POLICY unit_memberships_select ON core.unit_memberships
  FOR SELECT USING (
    is_deleted = false AND ((SELECT core.get_current_user_id()) = user_id OR core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id))
  );

CREATE POLICY unit_memberships_insert ON core.unit_memberships
  FOR INSERT WITH CHECK (
    core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id)
  );

CREATE POLICY unit_memberships_update ON core.unit_memberships
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id))
  )
  WITH CHECK (
    core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id)
  );

-- ========================================
-- POLICIES: audit_logs
-- ========================================
-- Org members can view audit logs (CASL can restrict further)
CREATE POLICY audit_logs_select ON core.audit_logs
  FOR SELECT USING (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: organization_files
-- ========================================
-- Org members can read/insert/update (CASL controls fine-grained access)
CREATE POLICY organization_files_select ON core.organization_files
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  );

CREATE POLICY organization_files_insert ON core.organization_files
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

CREATE POLICY organization_files_update ON core.organization_files
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  )
  WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: roles
-- ========================================
-- core.roles is shared reference data (role names + CASL rule definitions).
-- Any authenticated user needs SELECT access to resolve their role and
-- render UI based on CASL rules. There is no tenant scoping on this table.
-- INSERT/UPDATE/DELETE are not permitted via RLS — role mutations must go
-- through admin tooling/seed scripts.
CREATE POLICY roles_select ON core.roles
  FOR SELECT USING (is_deleted = false);
