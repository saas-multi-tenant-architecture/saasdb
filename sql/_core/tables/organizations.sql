-- organizations.sql
-- Purpose: Core tenant organizations table

-- ========================================
-- TABLE: core.organizations
-- ========================================
CREATE TABLE core.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_by uuid NOT NULL,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_organizations_updated
BEFORE UPDATE ON core.organizations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
