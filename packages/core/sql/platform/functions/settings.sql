-- settings.sql
-- Purpose: Platform functions for global settings management

-- ========================================
-- FUNCTION: platform.get_setting()
-- ========================================
-- Get a specific platform setting by key
CREATE OR REPLACE FUNCTION platform.get_setting(
  p_key TEXT
) RETURNS TEXT AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN (
    SELECT s.value::text
    FROM platform.platform_settings s
    WHERE s.key = p_key
      AND s.is_deleted = false
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.list_settings()
-- ========================================
-- List all platform settings
CREATE OR REPLACE FUNCTION platform.list_settings()
RETURNS TABLE (
  key TEXT,
  value JSONB,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN QUERY
  SELECT s.key, s.value, s.description, s.created_at, s.updated_at
  FROM platform.platform_settings s
  WHERE s.is_deleted = false
  ORDER BY s.key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.set_setting()
-- ========================================
-- Create or update a platform setting (upsert)
CREATE OR REPLACE FUNCTION platform.set_setting(
  p_key TEXT,
  p_value JSONB,
  p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_exists BOOLEAN;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := core.get_current_user_id();

  SELECT EXISTS (
    SELECT 1 FROM platform.platform_settings WHERE key = p_key AND is_deleted = false
  ) INTO v_exists;

  IF v_exists THEN
    UPDATE platform.platform_settings
    SET value = p_value,
        description = COALESCE(p_description, description),
        updated_by = v_actor_id,
        updated_at = now()
    WHERE key = p_key
      AND is_deleted = false;

    PERFORM platform.log_platform_action('update', 'platform.platform_settings', NULL,
      'set_setting', jsonb_build_object('key', p_key, 'action', 'update'));
  ELSE
    INSERT INTO platform.platform_settings (key, value, description, created_by, updated_by)
    VALUES (p_key, p_value, p_description, v_actor_id, v_actor_id);

    PERFORM platform.log_platform_action('create', 'platform.platform_settings', NULL,
      'set_setting', jsonb_build_object('key', p_key, 'action', 'create'));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_setting()
-- ========================================
-- Soft-delete a platform setting
CREATE OR REPLACE FUNCTION platform.delete_setting(
  p_key TEXT
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := core.get_current_user_id();

  UPDATE platform.platform_settings
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_actor_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE key = p_key
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Setting % not found or already deleted', p_key;
  END IF;

  PERFORM platform.log_platform_action('delete', 'platform.platform_settings', NULL,
    'delete_setting', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
