-- 006_organizations_meta.sql
-- Purpose: Metadata table for tenant organizations (1:1 with core.organizations)
-- Assumes utils schema is present for timestamp updates

-- ========================================
-- TABLE CREATION
-- ========================================
CREATE TABLE core.organizations_meta (
  id UUID PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  logo_file_id UUID REFERENCES core.organization_files(id) ON DELETE SET NULL,
  address TEXT,
  timezone TEXT,
  locale TEXT,
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
CREATE TRIGGER trg_organizations_meta_updated
BEFORE UPDATE ON core.organizations_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- 1:1 relationship with core.organizations
-- Holds organization-wide metadata accessible to members via RLS
