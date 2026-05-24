-- organizations.sql
-- Purpose: Platform control layer for tenant visibility

-- ========================================
-- TABLE: platform.platform_organizations
-- ========================================
CREATE TABLE platform.platform_organizations (
  id UUID PRIMARY KEY,
  label TEXT NOT NULL,
  notes TEXT,
  created_by uuid,
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
CREATE TRIGGER trg_platform_organizations_updated
BEFORE UPDATE ON platform.platform_organizations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
