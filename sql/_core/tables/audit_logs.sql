-- audit_logs.sql
-- Purpose: Central audit log for tracking user actions

-- ========================================
-- TABLE: core.audit_logs
-- ========================================
CREATE TABLE core.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID, -- auth.uid()
  organization_id UUID REFERENCES core.organizations(id),
  target_table TEXT NOT NULL,
  target_id UUID,
  action TEXT NOT NULL, -- 'insert', 'update', 'delete', 'login', etc.
  summary TEXT,
  metadata JSONB, -- optional structure: changed fields, reason, etc.
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_audit_logs_actor_id ON core.audit_logs (actor_id);
CREATE INDEX idx_audit_logs_organization_id ON core.audit_logs (organization_id);
CREATE INDEX idx_audit_logs_target_table ON core.audit_logs (target_table);
CREATE INDEX idx_audit_logs_metadata ON core.audit_logs USING GIN (metadata);

-- ========================================
-- NOTES
-- ========================================
-- No update trigger as audit logs should be immutable
