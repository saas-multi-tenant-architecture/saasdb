-- user_profile.sql
-- Purpose: Public RPC functions for user profile management

-- ========================================
-- FUNCTION: public.get_user_profile()
-- ========================================
-- Returns profile data for the current user
CREATE OR REPLACE FUNCTION public.get_user_profile()
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.email,
    m.first_name,
    m.last_name,
    m.avatar_url,
    m.timezone,
    m.locale
  FROM core.users_meta m
  WHERE m.id = core.get_current_user_id();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_user_profile()
-- ========================================
DROP FUNCTION IF EXISTS public.update_user_profile(JSON);
CREATE OR REPLACE FUNCTION public.update_user_profile(
  p_first_name TEXT,
  p_last_name TEXT
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  UPDATE core.users_meta AS um
  SET first_name = p_first_name,
      last_name  = p_last_name,
      updated_by = core.get_current_user_id()
  WHERE um.id = core.get_current_user_id();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;

  PERFORM core.log_audit('update', 'core.users_meta', core.get_current_user_id(), 'update_user_profile',
    jsonb_build_object('first_name', p_first_name, 'last_name', p_last_name));

  RETURN QUERY
  SELECT m.id, m.email, m.first_name, m.last_name, m.avatar_url, m.timezone, m.locale
  FROM core.users_meta m WHERE m.id = core.get_current_user_id();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_organizations()
-- ========================================
-- Returns all active organizations the current user belongs to.
CREATE OR REPLACE FUNCTION public.get_user_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.list_my_organizations();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_units()
-- ========================================
-- Returns units the current user belongs to within a specific organization.
CREATE OR REPLACE FUNCTION public.get_user_units(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND u.organization_id = p_org_id
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
