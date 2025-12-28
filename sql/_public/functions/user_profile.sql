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
  WHERE m.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_user_profile()
-- ========================================
-- Update profile fields for the current user
CREATE OR REPLACE FUNCTION public.update_user_profile(p_data JSON)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
DECLARE
  v_row core.users_meta%ROWTYPE;
BEGIN
  UPDATE core.users_meta
  SET first_name = COALESCE(p_data->>'first_name', first_name),
      last_name  = COALESCE(p_data->>'last_name', last_name),
      avatar_url = COALESCE(p_data->>'avatar_url', avatar_url),
      timezone   = COALESCE(p_data->>'timezone', timezone),
      locale     = COALESCE(p_data->>'locale', locale)
  WHERE id = auth.uid()
  RETURNING * INTO v_row;

  PERFORM core.log_audit('update', 'core.users_meta', auth.uid(), 'update_user_profile', p_data);

  RETURN QUERY SELECT
    v_row.id,
    (SELECT email FROM auth.users WHERE id = v_row.id),
    v_row.first_name,
    v_row.last_name,
    v_row.avatar_url,
    v_row.timezone,
    v_row.locale;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
