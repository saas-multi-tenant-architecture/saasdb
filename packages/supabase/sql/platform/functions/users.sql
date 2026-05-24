-- users.sql
-- Purpose: Platform functions for managing platform users

-- ========================================
-- FUNCTION: platform.create_platform_user()
-- ========================================
-- Add a new platform user with a specific role
-- New signature: (supabase_user_id, email, role_id)
-- NOTE: A legacy wrapper with the old signature (uuid, text) is retained below.
DROP FUNCTION IF EXISTS platform.create_platform_user(UUID, TEXT);
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_supabase_user_id UUID,
  p_email TEXT,
  p_role_id UUID
) RETURNS UUID AS $$
DECLARE
  v_platform_user_id UUID;
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  IF p_supabase_user_id IS NULL THEN
    RAISE EXCEPTION 'supabase_user_id is required';
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RAISE EXCEPTION 'email is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_supabase_user_id) THEN
    RAISE EXCEPTION 'User % not found', p_supabase_user_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM platform.platform_roles pr WHERE pr.id = p_role_id) THEN
    RAISE EXCEPTION 'Role % not found', p_role_id;
  END IF;

  INSERT INTO platform.platform_users (supabase_user_id, email, role_id, created_by, updated_by)
  VALUES (p_supabase_user_id, p_email, p_role_id, v_actor_id, v_actor_id)
  RETURNING id INTO v_platform_user_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_users', v_platform_user_id,
    'create_platform_user', jsonb_build_object('role_id', p_role_id, 'supabase_user_id', p_supabase_user_id, 'email', p_email));

  RETURN v_platform_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.create_platform_user() (legacy)
-- ========================================
-- Legacy signature: (supabase_user_id, role_name)
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_user_id UUID,
  p_role TEXT
) RETURNS UUID AS $$
DECLARE
  v_role_id UUID;
  v_email TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT pr.id INTO v_role_id
  FROM platform.platform_roles pr
  WHERE pr.name = p_role
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  SELECT u.email INTO v_email
  FROM auth.users u
  WHERE u.id = p_user_id;

  IF v_email IS NULL THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  RETURN platform.create_platform_user(p_user_id, v_email, v_role_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_platform_user()
-- ========================================
-- Change the assigned role_id for a platform user
CREATE OR REPLACE FUNCTION platform.update_platform_user(
  p_user_id UUID,
  p_role_id UUID
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_old_role TEXT;
  v_new_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get current role for audit
  SELECT pr.name INTO v_old_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pr.id = pu.role_id
  WHERE pu.id = p_user_id AND pu.is_deleted = false;

  SELECT pr.name INTO v_new_role
  FROM platform.platform_roles pr
  WHERE pr.id = p_role_id;

  IF v_new_role IS NULL THEN
    RAISE EXCEPTION 'Role % not found', p_role_id;
  END IF;

  UPDATE platform.platform_users
  SET role_id = p_role_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_user_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('update', 'platform.platform_users', p_user_id,
    'update_platform_user', jsonb_build_object('old_role', v_old_role, 'new_role', v_new_role, 'new_role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_platform_user_role() (legacy)
-- ========================================
CREATE OR REPLACE FUNCTION platform.update_platform_user_role(
  p_user_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_role_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT pr.id INTO v_role_id
  FROM platform.platform_roles pr
  WHERE pr.name = p_role
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  PERFORM platform.update_platform_user(p_user_id, v_role_id);
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
