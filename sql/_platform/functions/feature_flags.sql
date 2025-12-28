-- feature_flags.sql
-- Purpose: Platform function for feature flag management

-- ========================================
-- FUNCTION: platform.create_platform_feature_flag()
-- ========================================
-- Register a global or per-organization feature toggle
CREATE OR REPLACE FUNCTION platform.create_platform_feature_flag(
  p_key TEXT,
  p_value JSONB,
  p_organization_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.platform_feature_flags (key, value, organization_id)
  VALUES (p_key, p_value, p_organization_id)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_feature_flags', v_id,
    'create_platform_feature_flag', jsonb_build_object('organization_id', p_organization_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
