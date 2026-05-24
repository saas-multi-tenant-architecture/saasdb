-- system_events.sql
-- Purpose: Infrastructure-level activity or notices

-- ========================================
-- TABLE: platform.platform_system_events
-- ========================================
CREATE TABLE platform.platform_system_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  summary TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
