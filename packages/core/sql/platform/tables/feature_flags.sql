-- feature_flags.sql
-- Purpose: Global or per-organization feature toggles

-- ========================================
-- TABLE: platform.platform_feature_flags
-- ========================================
CREATE TABLE platform.platform_feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL,
  organization_id UUID REFERENCES platform.platform_organizations(id) ON DELETE CASCADE,
  description TEXT,
  value JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
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
CREATE INDEX ON platform.platform_feature_flags (organization_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_feature_flags_updated
BEFORE UPDATE ON platform.platform_feature_flags
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
