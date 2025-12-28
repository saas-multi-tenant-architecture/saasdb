-- log_audit.sql
-- Purpose: Helper function for audit logging

-- ========================================
-- FUNCTION: core.log_audit()
-- ========================================
CREATE OR REPLACE FUNCTION core.log_audit(
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.audit_logs (
    actor_id,
    target_table,
    target_id,
    action,
    summary,
    metadata
  ) VALUES (
    auth.uid(),
    target_table,
    target_id,
    action_type,
    summary,
    metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;
