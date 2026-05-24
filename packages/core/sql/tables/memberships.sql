-- memberships.sql
-- Purpose: User memberships in organizations and units

-- ========================================
-- TABLE: core.memberships
-- ========================================
CREATE TABLE core.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  is_super_admin BOOLEAN NOT NULL DEFAULT false,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, organization_id)
);

-- Ensure only one super_admin per organization
CREATE UNIQUE INDEX idx_one_super_admin_per_org
  ON core.memberships (organization_id)
  WHERE is_super_admin = true AND is_deleted = false;

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_memberships_user_id ON core.memberships (user_id);
CREATE INDEX idx_memberships_organization_id ON core.memberships (organization_id);
CREATE INDEX idx_memberships_role_id ON core.memberships (role_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_memberships_updated
BEFORE UPDATE ON core.memberships
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.unit_memberships
-- ========================================
CREATE TABLE core.unit_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  unit_id UUID NOT NULL REFERENCES core.units(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, unit_id)
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_unit_memberships_user_id ON core.unit_memberships (user_id);
CREATE INDEX idx_unit_memberships_unit_id ON core.unit_memberships (unit_id);
CREATE INDEX idx_unit_memberships_role_id ON core.unit_memberships (role_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_unit_memberships_updated
BEFORE UPDATE ON core.unit_memberships
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
