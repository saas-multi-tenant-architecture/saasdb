-- overrides.sql
-- Purpose: Platform functions for subscription overrides

-- ========================================
-- FUNCTION: platform.set_platform_override()
-- ========================================
-- Store or update a subscription override for an organization
CREATE OR REPLACE FUNCTION platform.set_platform_override(
  p_organization_id UUID,
  p_key TEXT,
  p_value JSONB
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_id FROM platform.platform_subscription_overrides
  WHERE organization_id = p_organization_id;

  IF v_id IS NULL THEN
    INSERT INTO platform.platform_subscription_overrides (organization_id, features)
    VALUES (p_organization_id, jsonb_build_object(p_key, p_value))
    RETURNING id INTO v_id;
  ELSE
    UPDATE platform.platform_subscription_overrides
    SET features = jsonb_set(COALESCE(features, '{}'), ARRAY[p_key], p_value, true),
        updated_at = now()
    WHERE id = v_id;
  END IF;

  PERFORM platform.log_platform_action('override', 'platform.platform_subscription_overrides', v_id,
    'set_platform_override', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_platform_override()
-- ========================================
-- Remove a subscription override
CREATE OR REPLACE FUNCTION platform.delete_platform_override(
  p_organization_id UUID,
  p_key TEXT
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_id FROM platform.platform_subscription_overrides
  WHERE organization_id = p_organization_id;

  IF v_id IS NOT NULL THEN
    UPDATE platform.platform_subscription_overrides
    SET features = COALESCE(features, '{}') - p_key,
        updated_at = now()
    WHERE id = v_id;
  END IF;

  PERFORM platform.log_platform_action('override', 'platform.platform_subscription_overrides', v_id,
    'delete_platform_override', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
