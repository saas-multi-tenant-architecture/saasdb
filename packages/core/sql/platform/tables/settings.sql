-- settings.sql
-- Purpose: Global key-value configuration for the platform

-- ========================================
-- TABLE: platform.platform_settings
-- ========================================
CREATE TABLE platform.platform_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
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
CREATE TRIGGER trg_platform_settings_updated
BEFORE UPDATE ON platform.platform_settings
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
