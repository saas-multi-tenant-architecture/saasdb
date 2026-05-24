-- audit.sql
-- Purpose: Public RPC function for audit log access

-- ========================================
-- FUNCTION: public.get_audit_log()
-- ========================================
-- Get audit log entries for an organization
CREATE OR REPLACE FUNCTION public.get_audit_log(p_org_id UUID, p_limit INT)
RETURNS TABLE (
  id UUID,
  actor_id UUID,
  target_table TEXT,
  target_id UUID,
  action TEXT,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, actor_id, target_table, target_id, action, summary, metadata, created_at
  FROM core.audit_logs
  WHERE organization_id = p_org_id
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
