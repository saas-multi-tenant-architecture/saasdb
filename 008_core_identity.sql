-- 008_core_identity.sql
-- Purpose: Core identity and access control tables
-- Includes organizations, units, memberships, roles, and audit logs
-- Requires utils schema for timestamp trigger

-- ========================================
-- TABLE: core.organizations
-- ========================================
CREATE TABLE core.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_by UUID,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_organizations_updated
BEFORE UPDATE ON core.organizations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.units
-- ========================================
CREATE TABLE core.units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_by UUID,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_units_updated
BEFORE UPDATE ON core.units
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.unit_meta
-- ========================================
CREATE TABLE core.unit_meta (
  id UUID PRIMARY KEY REFERENCES core.units(id) ON DELETE CASCADE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_unit_meta_updated
BEFORE UPDATE ON core.unit_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.roles
-- ========================================
CREATE TABLE core.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  priority INTEGER NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_roles_updated
BEFORE UPDATE ON core.roles
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.memberships
-- ========================================
CREATE TABLE core.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  created_by UUID,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, organization_id)
);

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
  created_by UUID,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, unit_id)
);

CREATE TRIGGER trg_unit_memberships_updated
BEFORE UPDATE ON core.unit_memberships
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.audit_logs
-- ========================================
CREATE TABLE core.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID,
  organization_id UUID REFERENCES core.organizations(id),
  target_table TEXT NOT NULL,
  target_id UUID,
  action TEXT NOT NULL,
  summary TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- No update trigger as audit logs should be immutable

