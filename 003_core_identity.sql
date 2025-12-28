-- 003_core_identity.sql
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
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
  description TEXT,
  casl_rules JSONB, -- JSONB column to store role CASL rules 
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER trg_roles_updated
BEFORE UPDATE ON core.roles
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- ========================================
-- CASL Rules Sample JSON Structure:
-- [
--   { "action": "read", "subject": "Ticket" },
--   { "action": ["update","close"], "subject": "Ticket" },
--   { "action": "delete", "subject": "Ticket", "inverted": true }
-- ]
-- ========================================


-- ========================================
-- TABLE: core.memberships
-- ========================================
CREATE TABLE core.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
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
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, unit_id)
);

CREATE TRIGGER trg_unit_memberships_updated
BEFORE UPDATE ON core.unit_memberships
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- ========================================
-- TABLE: core.files - Define table for storing references to organization-owned files stored in Supabase Storage
-- ========================================
CREATE TABLE core.organization_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- URL or storage path to the file in Supabase bucket
  file_url TEXT NOT NULL,
  -- MIME type (e.g. 'image/png', 'application/pdf')
  file_type TEXT NOT NULL,
  -- Optional structured info about the file (e.g., image dimensions, metadata)
  file_specs JSONB,
  -- Size in bytes
  file_size INTEGER,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- Indexes (optional but useful for querying by org or type)
-- ========================================
CREATE INDEX idx_organization_files_organization_id ON core.organization_files (organization_id);
CREATE INDEX idx_organization_files_file_type ON core.organization_files (file_type);

CREATE TRIGGER trg_organization_files_updated
BEFORE UPDATE ON core.organization_files
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- ========================================
-- TABLE: core.audit_logs
-- ========================================
CREATE TABLE core.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID, -- auth.uid()
  organization_id UUID REFERENCES core.organizations(id),
  target_table TEXT NOT NULL,
  target_id UUID,
  action TEXT NOT NULL, -- 'insert', 'update', 'delete', 'login', etc.
  summary TEXT,
  metadata JSONB, -- optional structure: changed fields, reason, etc.
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_audit_logs_metadata ON core.audit_logs USING GIN (metadata);

-- No update trigger as audit logs should be immutable

