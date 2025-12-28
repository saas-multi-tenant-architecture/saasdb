-- policies.sql
-- Purpose: Enable RLS and define policies for core tables

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

-- ========================================
-- POLICIES: users_meta
-- ========================================
-- Viewable by same org members, editable by owner
CREATE POLICY users_meta_select ON core.users_meta
  FOR SELECT USING (
    (SELECT auth.uid()) = id OR core.shares_organization(id)
  );

CREATE POLICY users_meta_update ON core.users_meta
  FOR UPDATE USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- ========================================
-- POLICIES: organizations_meta
-- ========================================
-- Viewable by org members, editable by org admins
CREATE POLICY organizations_meta_select ON core.organizations_meta
  FOR SELECT USING (core.is_org_member(id));

CREATE POLICY organizations_meta_update ON core.organizations_meta
  FOR UPDATE USING (core.has_org_role(id, 'admin'))
  WITH CHECK (core.has_org_role(id, 'admin'));

-- ========================================
-- POLICIES: organizations
-- ========================================
-- Members can read, admins can update
CREATE POLICY organizations_select ON core.organizations
  FOR SELECT USING (core.is_org_member(id));

CREATE POLICY organizations_update ON core.organizations
  FOR UPDATE USING (core.has_org_role(id, 'admin'))
  WITH CHECK (core.has_org_role(id, 'admin'));

CREATE POLICY organizations_insert ON core.organizations
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = created_by);

-- ========================================
-- POLICIES: units
-- ========================================
-- Org members read, admins insert/update
CREATE POLICY units_select ON core.units
  FOR SELECT USING (core.is_org_member(organization_id));

CREATE POLICY units_insert ON core.units
  FOR INSERT WITH CHECK (core.has_org_role(organization_id, 'admin'));

CREATE POLICY units_update ON core.units
  FOR UPDATE USING (core.has_org_role(organization_id, 'admin'))
  WITH CHECK (core.has_org_role(organization_id, 'admin'));

-- ========================================
-- POLICIES: unit_meta
-- ========================================
-- Unit members read, unit admins update
CREATE POLICY unit_meta_select ON core.unit_meta
  FOR SELECT USING (core.is_unit_member(id));

CREATE POLICY unit_meta_update ON core.unit_meta
  FOR UPDATE USING (core.has_unit_role(id, 'admin'))
  WITH CHECK (core.has_unit_role(id, 'admin'));

-- ========================================
-- POLICIES: memberships
-- ========================================
-- Users see their own rows, admins manage
CREATE POLICY memberships_select ON core.memberships
  FOR SELECT USING (
    (SELECT auth.uid()) = user_id OR core.has_org_role(organization_id, 'admin')
  );

CREATE POLICY memberships_insert ON core.memberships
  FOR INSERT WITH CHECK (core.has_org_role(organization_id, 'admin'));

CREATE POLICY memberships_update ON core.memberships
  FOR UPDATE USING (core.has_org_role(organization_id, 'admin'))
  WITH CHECK (core.has_org_role(organization_id, 'admin'));

-- ========================================
-- POLICIES: unit_memberships
-- ========================================
-- Similar logic scoped to unit
CREATE POLICY unit_memberships_select ON core.unit_memberships
  FOR SELECT USING (
   (SELECT auth.uid()) = user_id OR core.has_unit_role(unit_id, 'admin')
  );

CREATE POLICY unit_memberships_insert ON core.unit_memberships
  FOR INSERT WITH CHECK (core.has_unit_role(unit_id, 'admin'));

CREATE POLICY unit_memberships_update ON core.unit_memberships
  FOR UPDATE USING (core.has_unit_role(unit_id, 'admin'))
  WITH CHECK (core.has_unit_role(unit_id, 'admin'));

-- ========================================
-- POLICIES: audit_logs
-- ========================================
-- Org admins only
CREATE POLICY audit_logs_select ON core.audit_logs
  FOR SELECT USING (core.has_org_role(organization_id, 'admin'));

-- ========================================
-- POLICIES: organization_files
-- ========================================
-- Org members can read, admins can insert/update
CREATE POLICY organization_files_select ON core.organization_files
  FOR SELECT USING (core.is_org_member(organization_id));

CREATE POLICY organization_files_insert ON core.organization_files
  FOR INSERT WITH CHECK (core.has_org_role(organization_id, 'admin'));

CREATE POLICY organization_files_update ON core.organization_files
  FOR UPDATE USING (core.has_org_role(organization_id, 'admin'))
  WITH CHECK (core.has_org_role(organization_id, 'admin'));
