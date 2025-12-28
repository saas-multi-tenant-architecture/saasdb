-- log_action.sql
-- Purpose: Helper function for platform action logging

-- ========================================
-- FUNCTION: platform.log_platform_action()
-- ========================================
CREATE OR REPLACE FUNCTION platform.log_platform_action(
  p_action TEXT,
  p_target_table TEXT,
  p_target_id UUID,
  p_summary TEXT,
  p_metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_action_logs (
    platform_user_id,
    action_type,
    target_table,
    target_id,
    summary,
    metadata
  ) VALUES (
    auth.uid(),
    p_action,
    p_target_table,
    p_target_id,
    p_summary,
    p_metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
