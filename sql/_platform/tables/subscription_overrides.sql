-- subscription_overrides.sql
-- Purpose: Plan & feature overrides per organization

-- ========================================
-- TABLE: platform.platform_subscription_overrides
-- ========================================
CREATE TABLE platform.platform_subscription_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES platform.platform_organizations(id) ON DELETE CASCADE NOT NULL,
  plan_override TEXT NOT NULL,
  features JSONB NOT NULL,
  reason TEXT NOT NULL,
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
CREATE INDEX ON platform.platform_subscription_overrides (organization_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_subscription_overrides_updated
BEFORE UPDATE ON platform.platform_subscription_overrides
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
