-- action_logs.sql
-- Purpose: Tracks all platform admin activity

-- ========================================
-- TABLE: platform.platform_action_logs
-- ========================================
CREATE TABLE platform.platform_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_user_id UUID REFERENCES platform.platform_users(id) ON DELETE SET NULL,
  auth_user_id UUID REFERENCES platform.platform_users(user_id),
  action_type TEXT NOT NULL, -- enum: select, create, update, delete, log, override
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX ON platform.platform_action_logs (platform_user_id);
CREATE INDEX ON platform.platform_action_logs (auth_user_id);
