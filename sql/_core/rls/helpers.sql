-- helpers.sql
-- Purpose: RLS helper functions for membership and role checks

-- ========================================
-- FUNCTION: core.is_super_admin()
-- ========================================
-- Check if current user is super_admin for an organization
CREATE OR REPLACE FUNCTION core.is_super_admin(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = auth.uid()
      AND organization_id = p_org_id
      AND is_super_admin = true
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE
SET search_path = core;

-- ========================================
-- FUNCTION: core.is_org_member()
-- ========================================
CREATE OR REPLACE FUNCTION core.is_org_member(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = auth.uid()
      AND organization_id = p_org_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE
SET search_path = core

-- ========================================
-- FUNCTION: core.is_unit_member()
-- ========================================
CREATE OR REPLACE FUNCTION core.is_unit_member(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = auth.uid()
      AND unit_id = p_unit_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE
SET search_path = core

-- ========================================
-- FUNCTION: core.get_org_role()
-- ========================================
CREATE OR REPLACE FUNCTION core.get_org_role(p_org_id UUID)
RETURNS TEXT AS $$
  SELECT r.name
  FROM core.memberships m
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = auth.uid()
    AND m.organization_id = p_org_id
    AND m.is_deleted = false
  LIMIT 1;
$$ LANGUAGE sql STABLE
SET search_path = core

-- ========================================
-- FUNCTION: core.has_org_role()
-- ========================================
CREATE OR REPLACE FUNCTION core.has_org_role(p_org_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT core.get_org_role(p_org_id) = p_role;
$$ LANGUAGE sql STABLE
SET search_path = core

-- ========================================
-- FUNCTION: core.has_unit_role()
-- ========================================
CREATE OR REPLACE FUNCTION core.has_unit_role(p_unit_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = auth.uid()
      AND um.unit_id = p_unit_id
      AND um.is_deleted = false
      AND r.name = p_role
  );
$$ LANGUAGE sql STABLE
SET search_path = core

-- ========================================
-- FUNCTION: core.shares_organization()
-- ========================================
CREATE OR REPLACE FUNCTION core.shares_organization(p_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM core.memberships m1
    JOIN core.memberships m2 ON m1.organization_id = m2.organization_id
    WHERE m1.user_id = auth.uid()
      AND m2.user_id = p_user_id
      AND m1.is_deleted = false
      AND m2.is_deleted = false
  );
$$ LANGUAGE sql STABLE
SET search_path = core;

-- ========================================
-- FUNCTION: core.get_org_id_for_unit()
-- ========================================
-- Get the organization_id for a given unit
CREATE OR REPLACE FUNCTION core.get_org_id_for_unit(p_unit_id UUID)
RETURNS UUID AS $$
  SELECT organization_id FROM core.units WHERE id = p_unit_id AND is_deleted = false;
$$ LANGUAGE sql STABLE
SET search_path = core;

-- ========================================
-- FUNCTION: core.is_org_super_admin_for_unit()
-- ========================================
-- Check if current user is super_admin of the organization that owns this unit
CREATE OR REPLACE FUNCTION core.is_org_super_admin_for_unit(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT core.is_super_admin(core.get_org_id_for_unit(p_unit_id));
$$ LANGUAGE sql STABLE
SET search_path = core;

-- ========================================
-- FUNCTION: core.is_org_member_for_unit()
-- ========================================
-- Check if current user is a member of the organization that owns this unit
CREATE OR REPLACE FUNCTION core.is_org_member_for_unit(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT core.is_org_member(core.get_org_id_for_unit(p_unit_id));
$$ LANGUAGE sql STABLE
SET search_path = core
