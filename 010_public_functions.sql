-- 010_public_functions.sql
-- Purpose: Public RPC functions for CRUD operations on core tables
-- Provides client-facing API while enforcing RLS and audit logging

-- ========================================
-- HELPER FUNCTION: core.log_audit
-- ========================================
CREATE OR REPLACE FUNCTION core.log_audit(
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.audit_logs (
    actor_id,
    target_table,
    target_id,
    action,
    summary,
    metadata
  ) VALUES (
    auth.uid(),
    target_table,
    target_id,
    action_type,
    summary,
    metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- PUBLIC FUNCTIONS
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
    u.id,
    u.email,
    m.first_name,
    m.last_name,
    m.avatar_url,
    m.timezone,
    m.locale
  FROM auth.users u
  JOIN core.users_meta m ON u.id = m.id
  WHERE u.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- List organizations the current user belongs to
CREATE OR REPLACE FUNCTION public.list_my_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
) AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Get a single organization by id
CREATE OR REPLACE FUNCTION public.get_organization(p_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, name, description, created_at, updated_at
  FROM core.organizations
  WHERE id = p_id
    AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- List members of an organization
CREATE OR REPLACE FUNCTION public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT
) AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Get the role of the current user within an organization
CREATE OR REPLACE FUNCTION public.get_user_role(p_org_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN core.get_org_role(p_org_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Create a new organization and assign creator as admin
CREATE OR REPLACE FUNCTION public.create_organization(p_name TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  created_at TIMESTAMPTZ
) AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Invite another user to an organization
CREATE OR REPLACE FUNCTION public.invite_user_to_organization(p_email TEXT, p_role_id UUID)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Remove a user from an organization (soft delete)
CREATE OR REPLACE FUNCTION public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- List units for the current user
CREATE OR REPLACE FUNCTION public.list_my_units()
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
  WHERE um.user_id = auth.uid()
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Get unit metadata
CREATE OR REPLACE FUNCTION public.get_unit(p_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, name, description, created_at, updated_at
  FROM core.units
  WHERE id = p_id
    AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Create a new unit within an organization
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
  updated_by UUID,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
DECLARE
  v_unit_id UUID;
BEGIN
  INSERT INTO core.units (organization_id, name, description, created_by, updated_by)
  VALUES (p_org_id, p_name, p_description, auth.uid(), auth.uid())
  RETURNING id INTO v_unit_id;

  PERFORM core.log_audit('insert', 'core.units', v_unit_id, 'create_unit', jsonb_build_object('organization_id', p_org_id, 'name', p_name));

  RETURN QUERY SELECT id, organization_id, name, created_at FROM core.units WHERE id = v_unit_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Assign a user to a unit
CREATE OR REPLACE FUNCTION public.assign_user_to_unit(p_user_id UUID, p_unit_id UUID, p_role_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (p_user_id, p_unit_id, p_role_id, auth.uid());

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'assign_user_to_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Remove a user from a unit (soft delete)
CREATE OR REPLACE FUNCTION public.remove_user_from_unit(p_user_id UUID, p_unit_id UUID)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ========================================
-- FUNCTION: public.create_file
-- ========================================
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
) AS $$
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
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ========================================
-- FUNCTION: public.update_file_metadata
-- ========================================
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
) AS $$
BEGIN
  UPDATE core.organization_files
  SET
    file_specs = COALESCE(p_file_specs, file_specs),
    file_size = COALESCE(p_file_size, file_size),
    updated_by = auth.uid(),
    updated_at = now()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'update', 'core.organization_files', p_file_id, 'update_file_metadata',
    jsonb_build_object(
      'file_specs', p_file_specs,
      'file_size', p_file_size
    )
  );

  RETURN QUERY
  SELECT id, file_url, file_type, updated_at FROM core.organization_files WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ========================================
-- FUNCTION: public.get_file
-- ========================================
CREATE OR REPLACE FUNCTION public.get_file(p_file_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ========================================
-- FUNCTION: public.list_files  
-- ========================================
CREATE OR REPLACE FUNCTION public.list_files(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE organization_id = p_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ========================================
-- FUNCTION: public.delete_file
-- ========================================
CREATE OR REPLACE FUNCTION public.delete_file(p_file_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.organization_files
  SET
    is_deleted = true,
    deleted_at = now(),
    deleted_by = auth.uid()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'delete', 'core.organization_files', p_file_id, 'delete_file',
    jsonb_build_object(
      'file_id', p_file_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;


-- Get audit log entries for an organization
CREATE OR REPLACE FUNCTION public.get_audit_log(p_org_id UUID, p_limit INT)
RETURNS TABLE (
  id UUID,
  actor_id UUID,
  target_table TEXT,
  target_id UUID,
  action TEXT,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, actor_id, target_table, target_id, action, summary, metadata, created_at
  FROM core.audit_logs
  WHERE organization_id = p_org_id
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

