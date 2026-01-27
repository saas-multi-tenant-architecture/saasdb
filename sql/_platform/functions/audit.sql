-- audit.sql
-- Purpose: Platform functions for audit and role access

-- ========================================
-- FUNCTION: platform.get_platform_user_role()
-- ========================================
-- Returns the current user's platform role
CREATE OR REPLACE FUNCTION platform.get_platform_user_role()
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_user();

  SELECT pr.name INTO v_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pu.role_id = pr.id
  WHERE pu.supabase_user_id = auth.uid()
    AND pu.is_deleted = false;

  RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.get_platform_action_log()
-- ========================================
-- Fetch recent platform actions for monitoring or audit
CREATE OR REPLACE FUNCTION platform.get_platform_action_log(
  p_limit INT DEFAULT 100
) RETURNS TABLE (
  id UUID,
  platform_user_id UUID,
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  PERFORM platform.log_platform_action('select', 'platform.platform_action_logs', NULL,
    'get_platform_action_log', jsonb_build_object('limit', p_limit));

  RETURN QUERY
  SELECT id, platform_user_id, action_type, target_table, target_id,
         summary, metadata, created_at
  FROM platform.platform_action_logs
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
