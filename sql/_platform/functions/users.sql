-- users.sql
-- Purpose: Platform functions for managing platform users

-- ========================================
-- FUNCTION: platform.create_platform_user()
-- ========================================
-- Add a new platform user with a specific role
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_user_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_role_id UUID;
  v_email TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_role_id FROM platform.platform_roles WHERE name = p_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  INSERT INTO platform.platform_users (id, supabase_user_id, email, role_id)
  VALUES (p_user_id, p_user_id, v_email, v_role_id);

  PERFORM platform.log_platform_action('create', 'platform.platform_users', p_user_id,
    'create_platform_user', jsonb_build_object('role', p_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_platform_user_role()
-- ========================================
-- Change the assigned role for a platform user
CREATE OR REPLACE FUNCTION platform.update_platform_user_role(
  p_user_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_role_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_role_id FROM platform.platform_roles WHERE name = p_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  UPDATE platform.platform_users
  SET role_id = v_role_id,
      updated_at = now()
  WHERE id = p_user_id;

  PERFORM platform.log_platform_action('update', 'platform.platform_users', p_user_id,
    'update_platform_user_role', jsonb_build_object('role', p_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_platform_user()
-- ========================================
-- Soft-delete a platform user
CREATE OR REPLACE FUNCTION platform.delete_platform_user(
  p_user_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  DELETE FROM platform.platform_users
  WHERE id = p_user_id;

  PERFORM platform.log_platform_action('delete', 'platform.platform_users', p_user_id,
    'delete_platform_user', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
