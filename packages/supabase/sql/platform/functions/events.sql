-- events.sql
-- Purpose: Platform function for system event logging

-- ========================================
-- FUNCTION: platform.log_platform_event()
-- ========================================
-- Record a system-level or admin-triggered event
CREATE OR REPLACE FUNCTION platform.log_platform_event(
  p_event_type TEXT,
  p_message TEXT,
  p_metadata JSONB
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.platform_system_events (event_type, summary, details)
  VALUES (p_event_type, p_message, p_metadata)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('log', 'platform.platform_system_events', v_id,
    'log_platform_event', jsonb_build_object('event_type', p_event_type));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
