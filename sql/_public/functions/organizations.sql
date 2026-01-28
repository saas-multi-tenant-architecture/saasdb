-- organizations.sql
-- Purpose: Public RPC functions for organization management

-- ========================================
-- FUNCTION: public.list_my_organizations()
-- ========================================
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
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_organization()
-- ========================================
-- Get a single organization by id
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
) AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.name, o.description, o.created_by, o.updated_by, o.is_deleted, o.deleted_at, o.deleted_by, o.created_at, o.updated_at
  FROM core.organizations o
  WHERE o.id = p_id
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_organization_members()
-- ========================================
-- List members of an organization
CREATE OR REPLACE FUNCTION public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  is_super_admin BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT m.user_id,
         um.email,
         um.first_name,
         um.last_name,
         r.name AS role,
         m.is_super_admin
  FROM core.memberships m
  JOIN core.users_meta um ON um.id = m.user_id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.organization_id = p_id
    AND m.is_deleted = false
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_role()
-- ========================================
-- Get the role of the current user within an organization
CREATE OR REPLACE FUNCTION public.get_user_role(p_org_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN core.get_org_role(p_org_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.create_organization()
-- ========================================
-- Create a new organization and assign creator as super_admin
-- NOTE: This function previously accepted (p_name TEXT, p_role_id UUID).
-- We drop that signature to avoid overload ambiguity.
DROP FUNCTION IF EXISTS public.create_organization(TEXT, UUID);
CREATE OR REPLACE FUNCTION public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  name TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_org_id UUID;
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Organization name is required';
  END IF;

  -- Avoid INSERT .. RETURNING here.
  -- The org membership is seeded in an AFTER INSERT trigger, and the RETURNING clause
  -- would require SELECT access to the new org row before that membership exists.
  v_org_id := gen_random_uuid();

  INSERT INTO core.organizations (id, name, description, created_by, updated_by)
  VALUES (v_org_id, p_name, p_description, auth.uid(), auth.uid());

  -- Membership + platform registry rows are created by core.handle_new_organization() trigger.
  PERFORM core.log_audit(
    'insert',
    'core.organizations',
    v_org_id,
    'create_organization',
    jsonb_build_object('name', p_name, 'description', p_description)
  );

  RETURN QUERY SELECT core.organizations.id, core.organizations.name, core.organizations.created_at FROM core.organizations WHERE core.organizations.id = v_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.invite_user_to_organization()
-- ========================================
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
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_user_from_organization()
-- ========================================
-- Remove a user from an organization (soft delete)
-- Note: Cannot remove super_admin - must transfer first
CREATE OR REPLACE FUNCTION public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
RETURNS VOID AS $$
BEGIN
  -- RLS and protect_super_admin trigger will enforce permissions
  UPDATE core.memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid()
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.memberships', p_user_id, 'remove_user_from_organization', jsonb_build_object('organization_id', p_org_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.transfer_super_admin()
-- ========================================
-- Transfer super_admin status to another organization member
-- Only the current super_admin can perform this action
CREATE OR REPLACE FUNCTION public.transfer_super_admin(p_org_id UUID, p_new_super_admin_user_id UUID)
RETURNS VOID AS $$
DECLARE
  v_current_user_id UUID;
  v_target_membership_exists BOOLEAN;
  v_target_membership_is_deleted BOOLEAN;
BEGIN
  v_current_user_id := auth.uid();

  -- Verify caller is current super_admin
  IF NOT core.is_super_admin(p_org_id) THEN
    RAISE EXCEPTION 'Only the current super_admin can transfer ownership';
  END IF;

  -- Verify target user is a member of the organization
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = p_new_super_admin_user_id
      AND organization_id = p_org_id
      AND is_deleted = false
  ) INTO v_target_membership_exists;

  IF NOT v_target_membership_exists THEN
    RAISE EXCEPTION 'Target user is not a member of this organization';
  END IF;

  -- Cannot transfer to self
  IF v_current_user_id = p_new_super_admin_user_id THEN
    RAISE EXCEPTION 'Cannot transfer super_admin to yourself';
  END IF;

  -- Perform atomic transfer in a SINGLE statement
  -- This ensures RLS is checked once (when caller is still super_admin)
  -- and both updates happen atomically
  UPDATE core.memberships
  SET is_super_admin = CASE
        WHEN user_id = p_new_super_admin_user_id THEN true
        WHEN user_id = v_current_user_id THEN false
      END,
      updated_by = v_current_user_id,
      updated_at = now()
  WHERE organization_id = p_org_id
    AND user_id IN (v_current_user_id, p_new_super_admin_user_id)
    AND is_deleted = false;

  PERFORM core.log_audit(
    'update',
    'core.memberships',
    p_new_super_admin_user_id,
    'transfer_super_admin',
    jsonb_build_object(
      'organization_id', p_org_id,
      'previous_super_admin', v_current_user_id,
      'new_super_admin', p_new_super_admin_user_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_organization()
-- ========================================
-- Update an organization (super_admin only)
CREATE OR REPLACE FUNCTION public.update_organization(
  p_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Organization id is required';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Organization name is required';
  END IF;

  -- Prevent leaking whether an org exists to non-members
  IF NOT core.is_org_member(p_id) THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  IF NOT core.is_super_admin(p_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update the organization';
  END IF;

  UPDATE core.organizations as o
  SET name = p_name,
      description = p_description,
      updated_by = auth.uid()
  WHERE o.id = p_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  PERFORM core.log_audit(
    'update',
    'core.organizations',
    p_id,
    'update_organization',
    jsonb_build_object('name', p_name, 'description', p_description)
  );

  RETURN QUERY
  SELECT o.id, o.name, o.description, o.updated_at
  FROM core.organizations o
  WHERE o.id = p_id
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_organization_meta()
-- ========================================
-- Update organization metadata (super_admin only)
CREATE OR REPLACE FUNCTION public.update_organization_meta(
  p_id UUID,
  p_logo_file_id UUID DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_timezone TEXT DEFAULT NULL,
  p_locale TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  logo_file_id UUID,
  address TEXT,
  timezone TEXT,
  locale TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Organization id is required';
  END IF;

  -- Prevent leaking whether an org exists to non-members
  IF NOT core.is_org_member(p_id) THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  IF NOT core.is_super_admin(p_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update the organization';
  END IF;

  IF p_logo_file_id IS NOT NULL THEN
    PERFORM 1
    FROM core.organization_files of
    WHERE of.id = p_logo_file_id
      AND of.organization_id = p_id
      AND of.is_deleted = false;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid logo_file_id for this organization';
    END IF;
  END IF;

  UPDATE core.organizations_meta om
  SET logo_file_id = p_logo_file_id,
      address = p_address,
      timezone = p_timezone,
      locale = p_locale,
      updated_by = auth.uid()
  WHERE om.id = p_id
    AND om.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  PERFORM core.log_audit(
    'update',
    'core.organizations_meta',
    p_id,
    'update_organization_meta',
    jsonb_build_object(
      'logo_file_id', p_logo_file_id,
      'address', p_address,
      'timezone', p_timezone,
      'locale', p_locale
    )
  );

  RETURN QUERY
  SELECT om.id, om.logo_file_id, om.address, om.timezone, om.locale, om.updated_at
  FROM core.organizations_meta om
  WHERE om.id = p_id
    AND om.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_organization()
-- ========================================
-- Soft-delete an organization and related tenant data (super_admin only)
-- Intended to be the "shut off subscription" operation.
CREATE OR REPLACE FUNCTION public.delete_organization(p_id UUID)
RETURNS VOID AS $$
DECLARE
  v_unit_ids UUID[];
  v_org_meta_rows INT := 0;
  v_unit_meta_rows INT := 0;
  v_unit_membership_rows INT := 0;
  v_unit_rows INT := 0;
  v_org_file_rows INT := 0;
  v_cleared_super_admin_rows INT := 0;
  v_membership_rows INT := 0;
  v_membership_rows_self INT := 0;
  v_org_rows INT := 0;
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Organization id is required';
  END IF;

  -- Prevent leaking whether an org exists to non-members
  IF NOT core.is_org_member(p_id) THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  IF NOT core.is_super_admin(p_id) THEN
    RAISE EXCEPTION 'Only a super_admin can delete the organization';
  END IF;

  -- Ensure org exists and is active
  PERFORM 1
  FROM core.organizations AS o
  WHERE o.id = p_id
    AND o.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  SELECT COALESCE(array_agg(u.id), ARRAY[]::uuid[])
  INTO v_unit_ids
  FROM core.units u
  WHERE u.organization_id = p_id
    AND u.is_deleted = false;

  -- Soft-delete organizations_meta first (1:1)
  UPDATE core.organizations_meta AS o
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE o.id = p_id
    AND o.is_deleted = false;
  GET DIAGNOSTICS v_org_meta_rows = ROW_COUNT;

  -- Soft-delete units and their dependent rows while units are still active
  IF array_length(v_unit_ids, 1) IS NOT NULL AND array_length(v_unit_ids, 1) > 0 THEN
    UPDATE core.unit_meta AS u
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = auth.uid(),
        updated_by = auth.uid()
    WHERE u.id = ANY (v_unit_ids)
      AND u.is_deleted = false;
    GET DIAGNOSTICS v_unit_meta_rows = ROW_COUNT;

    UPDATE core.unit_memberships AS m
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = auth.uid(),
        updated_by = auth.uid()
    WHERE m.unit_id = ANY (v_unit_ids)
      AND m.is_deleted = false;
    GET DIAGNOSTICS v_unit_membership_rows = ROW_COUNT;

    UPDATE core.units AS u
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = auth.uid(),
        updated_by = auth.uid()
    WHERE u.id = ANY (v_unit_ids)
      AND u.is_deleted = false;
    GET DIAGNOSTICS v_unit_rows = ROW_COUNT;
  END IF;

  -- Soft-delete org files
  UPDATE core.organization_files AS f
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE f.organization_id = p_id
    AND f.is_deleted = false;
  GET DIAGNOSTICS v_org_file_rows = ROW_COUNT;

  -- protect_super_admin trigger blocks soft-delete of a super_admin membership.
  -- Clear the flag for the caller first.
  UPDATE core.memberships AS m
  SET is_super_admin = false,
      updated_by = auth.uid()
  WHERE m.organization_id = p_id
    AND m.user_id = auth.uid()
    AND m.is_super_admin = true
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_cleared_super_admin_rows = ROW_COUNT;

  -- Soft-delete all org memberships (including the former super_admin)
  -- Keep the caller membership active until the end of the process.
  UPDATE core.memberships AS m
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE m.organization_id = p_id
    AND m.user_id <> auth.uid()
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_membership_rows = ROW_COUNT;

  UPDATE core.memberships AS m
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE m.organization_id = p_id
    AND m.user_id = auth.uid()
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_membership_rows_self = ROW_COUNT;

  v_membership_rows := v_membership_rows + v_membership_rows_self;

  -- Finally, soft-delete the organization
  UPDATE core.organizations AS o
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE o.id = p_id
    AND o.is_deleted = false;
  GET DIAGNOSTICS v_org_rows = ROW_COUNT;

  PERFORM core.log_audit(
    'delete',
    'core.organizations',
    p_id,
    'delete_organization',
    jsonb_build_object(
      'organizations_meta_rows', v_org_meta_rows,
      'unit_meta_rows', v_unit_meta_rows,
      'unit_membership_rows', v_unit_membership_rows,
      'unit_rows', v_unit_rows,
      'organization_file_rows', v_org_file_rows,
      'cleared_super_admin_rows', v_cleared_super_admin_rows,
      'membership_rows', v_membership_rows,
      'organization_rows', v_org_rows
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
