-- feature_flags.sql
-- Purpose: Platform function for feature flag management

-- ========================================
-- FUNCTION: platform.create_platform_feature_flag()
-- ========================================
-- Register a global or per-organization feature toggle
CREATE OR REPLACE FUNCTION platform.create_platform_feature_flag(
  p_key TEXT,
  p_value JSONB,
  p_organization_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  INSERT INTO platform.platform_feature_flags (key, value, organization_id, description, created_by, updated_by)
  VALUES (p_key, p_value, p_organization_id, p_description, v_actor_id, v_actor_id)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_feature_flags', v_id,
    'create_platform_feature_flag', jsonb_build_object('key', p_key, 'organization_id', p_organization_id));

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.get_feature_flag()
-- ========================================
-- Get a specific feature flag by key and optional organization
CREATE OR REPLACE FUNCTION platform.get_feature_flag(
  p_key TEXT,
  p_organization_id UUID DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  key TEXT,
  value JSONB,
  organization_id UUID,
  description TEXT,
  is_active BOOLEAN
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN QUERY
  SELECT ff.id, ff.key, ff.value, ff.organization_id, ff.description, ff.is_active
  FROM platform.platform_feature_flags ff
  WHERE ff.key = p_key
    AND (ff.organization_id = p_organization_id OR (p_organization_id IS NULL AND ff.organization_id IS NULL))
    AND ff.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.list_feature_flags()
-- ========================================
-- List all feature flags, optionally filtered by organization
-- Does NOT include Global flags for a specific organization unless p_include_global is true
CREATE OR REPLACE FUNCTION platform.list_feature_flags(
  p_organization_id UUID DEFAULT NULL,
  p_include_global BOOLEAN DEFAULT false
) RETURNS TABLE (
  id UUID,
  key TEXT,
  value JSONB,
  organization_id UUID,
  description TEXT,
  is_active BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN QUERY
  SELECT ff.id, ff.key, ff.value, ff.organization_id, ff.description, ff.is_active, ff.created_at
  FROM platform.platform_feature_flags ff
  WHERE ff.is_deleted = false
    AND (
      (p_organization_id IS NULL) OR
      (ff.organization_id = p_organization_id) OR
      (p_include_global AND ff.organization_id IS NULL)
    )
  ORDER BY ff.key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_feature_flag()
-- ========================================
-- Update an existing feature flag
CREATE OR REPLACE FUNCTION platform.update_feature_flag(
  p_id UUID,
  p_value JSONB DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  UPDATE platform.platform_feature_flags
  SET value = COALESCE(p_value, value),
      is_active = COALESCE(p_is_active, is_active),
      description = COALESCE(p_description, description),
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('update', 'platform.platform_feature_flags', p_id,
    'update_feature_flag', jsonb_build_object('value', p_value, 'is_active', p_is_active));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_feature_flag()
-- ========================================
-- Soft-delete a feature flag
CREATE OR REPLACE FUNCTION platform.delete_feature_flag(
  p_id UUID
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_key TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get key for audit
  SELECT key INTO v_key FROM platform.platform_feature_flags WHERE id = p_id AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Feature flag % not found or already deleted', p_id;
  END IF;

  UPDATE platform.platform_feature_flags
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_actor_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('delete', 'platform.platform_feature_flags', p_id,
    'delete_feature_flag', jsonb_build_object('key', v_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
