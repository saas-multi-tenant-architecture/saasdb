-- users.sql
-- Purpose: Platform functions for managing platform users

-- ========================================
-- FUNCTION: platform.create_platform_user()
-- ========================================
-- Add a new platform user with a specific role
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_user_id UUID,
  p_role TEXT
) RETURNS UUID AS $$
DECLARE
  v_role_id UUID;
  v_email TEXT;
  v_platform_user_id UUID;
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  SELECT id INTO v_role_id FROM platform.platform_roles WHERE name = p_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  INSERT INTO platform.platform_users (supabase_user_id, email, role_id, created_by, updated_by)
  VALUES (p_user_id, v_email, v_role_id, v_actor_id, v_actor_id)
  RETURNING id INTO v_platform_user_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_users', v_platform_user_id,
    'create_platform_user', jsonb_build_object('role', p_role, 'supabase_user_id', p_user_id));

  RETURN v_platform_user_id;
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
  v_actor_id UUID;
  v_old_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get current role for audit
  SELECT pr.name INTO v_old_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pr.id = pu.role_id
  WHERE pu.id = p_user_id AND pu.is_deleted = false;

  SELECT id INTO v_role_id FROM platform.platform_roles WHERE name = p_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  UPDATE platform.platform_users
  SET role_id = v_role_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_user_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('update', 'platform.platform_users', p_user_id,
    'update_platform_user_role', jsonb_build_object('old_role', v_old_role, 'new_role', p_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_platform_user()
-- ========================================
-- Soft-delete a platform user
CREATE OR REPLACE FUNCTION platform.delete_platform_user(
  p_user_id UUID
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_user_email TEXT;
  v_user_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get user details for audit trail before soft-delete
  SELECT pu.email, pr.name INTO v_user_email, v_user_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pr.id = pu.role_id
  WHERE pu.id = p_user_id AND pu.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform user % not found or already deleted', p_user_id;
  END IF;

  -- Soft-delete the platform user
  UPDATE platform.platform_users
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_actor_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_user_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('delete', 'platform.platform_users', p_user_id,
    'delete_platform_user', jsonb_build_object('email', v_user_email, 'role', v_user_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;
