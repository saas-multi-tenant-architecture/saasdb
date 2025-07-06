-- 009_rls_policies.sql
-- Purpose: Define helper functions and RLS policies for tenant isolation

-- ========================================
-- HELPER FUNCTIONS
-- ========================================
CREATE OR REPLACE FUNCTION core.is_org_member(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = auth.uid()
      AND organization_id = p_org_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION core.is_unit_member(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = auth.uid()
      AND unit_id = p_unit_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION core.get_org_role(p_org_id UUID)
RETURNS TEXT AS $$
  SELECT r.name
  FROM core.memberships m
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = auth.uid()
    AND m.organization_id = p_org_id
    AND m.is_deleted = false
  LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION core.has_org_role(p_org_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT core.get_org_role(p_org_id) = p_role;
$$ LANGUAGE sql STABLE;

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
$$ LANGUAGE sql STABLE;

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
$$ LANGUAGE sql STABLE;

-- ========================================
-- RLS ENABLEMENT
-- ========================================
ALTER TABLE core.users_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organization_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.audit_logs ENABLE ROW LEVEL SECURITY;

-- ========================================
-- RLS POLICIES
-- ========================================
-- users_meta: viewable by same org members, editable by owner
CREATE POLICY users_meta_select ON core.users_meta
  FOR SELECT USING (
    auth.uid() = id OR core.shares_organization(id)
  );

CREATE POLICY users_meta_update ON core.users_meta
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- organization_meta: viewable by org members, editable by org admins
CREATE POLICY organization_meta_select ON core.organization_meta
  FOR SELECT USING (core.is_org_member(id));

CREATE POLICY organization_meta_update ON core.organization_meta
  FOR UPDATE USING (core.has_org_role(id, 'admin'))
  WITH CHECK (core.has_org_role(id, 'admin'));

-- organizations: members can read, admins can update
CREATE POLICY organizations_select ON core.organizations
  FOR SELECT USING (core.is_org_member(id));

CREATE POLICY organizations_update ON core.organizations
  FOR UPDATE USING (core.has_org_role(id, 'admin'))
  WITH CHECK (core.has_org_role(id, 'admin'));

CREATE POLICY organizations_insert ON core.organizations
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- units: org members read, admins insert/update
CREATE POLICY units_select ON core.units
  FOR SELECT USING (core.is_org_member(organization_id));

CREATE POLICY units_insert ON core.units
  FOR INSERT WITH CHECK (core.has_org_role(organization_id, 'admin'));

CREATE POLICY units_update ON core.units
  FOR UPDATE USING (core.has_org_role(organization_id, 'admin'))
  WITH CHECK (core.has_org_role(organization_id, 'admin'));

-- unit_meta: unit members read, unit admins update
CREATE POLICY unit_meta_select ON core.unit_meta
  FOR SELECT USING (core.is_unit_member(id));

CREATE POLICY unit_meta_update ON core.unit_meta
  FOR UPDATE USING (core.has_unit_role(id, 'admin'))
  WITH CHECK (core.has_unit_role(id, 'admin'));

-- memberships: users see their own rows, admins manage
CREATE POLICY memberships_select ON core.memberships
  FOR SELECT USING (
    user_id = auth.uid() OR core.has_org_role(organization_id, 'admin')
  );

CREATE POLICY memberships_insert ON core.memberships
  FOR INSERT WITH CHECK (core.has_org_role(organization_id, 'admin'));

CREATE POLICY memberships_update ON core.memberships
  FOR UPDATE USING (core.has_org_role(organization_id, 'admin'))
  WITH CHECK (core.has_org_role(organization_id, 'admin'));

-- unit_memberships: similar logic scoped to unit
CREATE POLICY unit_memberships_select ON core.unit_memberships
  FOR SELECT USING (
    user_id = auth.uid() OR core.has_unit_role(unit_id, 'admin')
  );

CREATE POLICY unit_memberships_insert ON core.unit_memberships
  FOR INSERT WITH CHECK (core.has_unit_role(unit_id, 'admin'));

CREATE POLICY unit_memberships_update ON core.unit_memberships
  FOR UPDATE USING (core.has_unit_role(unit_id, 'admin'))
  WITH CHECK (core.has_unit_role(unit_id, 'admin'));

-- audit_logs: org admins only
CREATE POLICY audit_logs_select ON core.audit_logs
  FOR SELECT USING (core.has_org_role(organization_id, 'admin'));

