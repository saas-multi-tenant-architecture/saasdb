-- organization_files.sql
-- Purpose: References to organization-owned files stored in Supabase Storage

-- ========================================
-- TABLE: core.organization_files
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
-- INDEXES
-- ========================================
CREATE INDEX idx_organization_files_organization_id ON core.organization_files (organization_id);
CREATE INDEX idx_organization_files_file_type ON core.organization_files (file_type);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_organization_files_updated
BEFORE UPDATE ON core.organization_files
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
