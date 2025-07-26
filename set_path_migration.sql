-- Migration: Fix role mutable search_path for all affected functions
-- This script ensures all listed functions have an explicit SET search_path clause.
-- Run this file on your Supabase/Postgres instance.

-- =====================
-- public.get_user_profile
-- =====================
CREATE OR REPLACE FUNCTION public.get_user_profile()
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
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
$$;

-- =====================
-- public.update_user_profile
-- =====================
CREATE OR REPLACE FUNCTION public.update_user_profile(p_data JSON)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
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
$$;

-- =====================
-- public.list_my_organizations
-- =====================
CREATE OR REPLACE FUNCTION public.list_my_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.name, o.description, r.name AS role
  FROM core.organizations o
  JOIN core.memberships m ON m.organization_id = o.id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = auth.uid()
    AND m.is_deleted = false
    AND o.is_deleted = false;
END;
$$;

-- =====================
-- public.get_organization
-- =====================
CREATE OR REPLACE FUNCTION public.get_organization(p_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  updated_by UUID,
  is_deleted BOOLEAN,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT id, name, description, created_by, created_at, updated_by, updated_at, is_deleted, deleted_at, deleted_by
  FROM core.organizations
  WHERE id = p_id
    AND is_deleted = false;
END;
$$;

-- =====================
-- public.list_organization_members
-- =====================
CREATE OR REPLACE FUNCTION public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT m.user_id,
         u.email,
         um.first_name,
         um.last_name,
         r.name AS role
  FROM core.memberships m
  JOIN auth.users u ON u.id = m.user_id
  JOIN core.users_meta um ON um.id = m.user_id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.organization_id = p_id
    AND m.is_deleted = false;
END;
$$;

-- =====================
-- public.get_user_role
-- =====================
CREATE OR REPLACE FUNCTION public.get_user_role(p_org_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN core.get_org_role(p_org_id);
END;
$$;

-- =====================
-- public.create_organization
-- =====================
CREATE OR REPLACE FUNCTION public.create_organization(p_name TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_org_id UUID;
  v_admin_role UUID;
BEGIN
  INSERT INTO core.organizations (name, created_by)
  VALUES (p_name, auth.uid())
  RETURNING id INTO v_org_id;

  SELECT id INTO v_admin_role FROM core.roles WHERE name = 'admin' LIMIT 1;
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (auth.uid(), v_org_id, v_admin_role, auth.uid());

  PERFORM core.log_audit('insert', 'core.organizations', v_org_id, 'create_organization', jsonb_build_object('name', p_name));

  RETURN QUERY SELECT id, name, created_at FROM core.organizations WHERE id = v_org_id;
END;
$$;

-- =====================
-- public.invite_user_to_organization
-- =====================
CREATE OR REPLACE FUNCTION public.invite_user_to_organization(p_email TEXT, p_role_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_org_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  SELECT organization_id INTO v_org_id FROM core.memberships
  WHERE user_id = auth.uid() AND is_deleted = false
  LIMIT 1;

  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_user_id, v_org_id, p_role_id, auth.uid());

  PERFORM core.log_audit('insert', 'core.memberships', v_user_id, 'invite_user_to_organization', jsonb_build_object('organization_id', v_org_id));
END;
$$;

-- =====================
-- public.remove_user_from_organization
-- =====================
CREATE OR REPLACE FUNCTION public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  UPDATE core.memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid()
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.memberships', p_user_id, 'remove_user_from_organization', jsonb_build_object('organization_id', p_org_id));
END;
$$;

-- =====================
-- public.list_my_units
-- =====================
CREATE OR REPLACE FUNCTION public.list_my_units()
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = auth.uid()
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$;

-- =====================
-- public.get_unit
-- =====================
CREATE OR REPLACE FUNCTION public.get_unit(p_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, name, description, created_at, updated_at
  FROM core.units
  WHERE id = p_id
    AND is_deleted = false;
END;
$$;

-- =====================
-- public.create_unit
-- =====================
CREATE OR REPLACE FUNCTION public.create_unit(
  p_org_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  updated_by UUID
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_unit_id UUID;
BEGIN
  INSERT INTO core.units (organization_id, name, description, created_by, updated_by)
  VALUES (p_org_id, p_name, p_description, auth.uid(), auth.uid())
  RETURNING id INTO v_unit_id;

  PERFORM core.log_audit('insert', 'core.units', v_unit_id, 'create_unit', jsonb_build_object('organization_id', p_org_id, 'name', p_name));

  RETURN QUERY SELECT id, organization_id, name, created_by, updated_by FROM core.units WHERE id = v_unit_id;
END;
$$;

-- =====================
-- public.assign_user_to_unit
-- =====================
CREATE OR REPLACE FUNCTION public.assign_user_to_unit(p_user_id UUID, p_unit_id UUID, p_role_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (p_user_id, p_unit_id, p_role_id, auth.uid());

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'assign_user_to_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$;

-- =====================
-- public.remove_user_from_unit
-- =====================
CREATE OR REPLACE FUNCTION public.remove_user_from_unit(p_user_id UUID, p_unit_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  UPDATE core.unit_memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_user_from_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$;

-- =====================
-- public.create_file
-- =====================
CREATE OR REPLACE FUNCTION public.create_file(
  p_org_id UUID,
  p_file_url TEXT,
  p_file_type TEXT,
  p_file_size INTEGER DEFAULT NULL,
  p_file_specs JSONB DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_file_id UUID;
BEGIN
  INSERT INTO core.organization_files (
    organization_id, file_url, file_type, file_size, file_specs, created_by
  )
  VALUES (
    p_org_id, p_file_url, p_file_type, p_file_size, p_file_specs, auth.uid()
  )
  RETURNING id INTO v_file_id;

  PERFORM core.log_audit(
    'insert', 'core.organization_files', v_file_id, 'create_file',
    jsonb_build_object(
      'file_url', p_file_url,
      'file_type', p_file_type,
      'file_size', p_file_size,
      'file_specs', p_file_specs
    )
  );

  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at
  FROM core.organization_files
  WHERE id = v_file_id;
END;
$$;

-- =====================
-- public.update_file_metadata
-- =====================
CREATE OR REPLACE FUNCTION public.update_file_metadata(
  p_file_id UUID,
  p_file_specs JSONB DEFAULT NULL,
  p_file_size INTEGER DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  file_url TEXT,
  file_type TEXT,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  UPDATE core.organization_files
  SET
    file_specs = COALESCE(p_file_specs, file_specs),
    file_size = COALESCE(p_file_size, file_size),
    updated_by = auth.uid(),
    updated_at = now()
  WHERE id = p_file_id;

  RETURN QUERY
  SELECT id, file_url, file_type, updated_at
  FROM core.organization_files
  WHERE id = p_file_id;
END;
$$;

-- =====================
-- public.get_file
-- =====================
CREATE OR REPLACE FUNCTION public.get_file(p_file_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE id = p_file_id;
END;
$$;
