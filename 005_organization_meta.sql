-- 005_organization_meta.sql
-- Purpose: Metadata table for tenant organizations (1:1 with app.organizations)
-- Assumes utils schema is present for timestamp updates

-- ========================================
-- TABLE CREATION
-- ========================================
CREATE TABLE app.organization_meta (
  id UUID PRIMARY KEY REFERENCES app.organizations(id) ON DELETE CASCADE,
  logo_url TEXT,
  address TEXT,
  timezone TEXT,
  locale TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_organization_meta_updated
BEFORE UPDATE ON app.organization_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- 1:1 relationship with app.organizations
-- Holds organization-wide metadata accessible to members via RLS
