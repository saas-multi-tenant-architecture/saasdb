-- units.sql
-- Purpose: Public RPC functions for unit management
-- Note: RLS validates org/unit membership; CASL handles fine-grained permissions

-- ========================================
-- FUNCTION: public.list_my_units()
-- ========================================
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
  WHERE um.user_id = core.get_current_user_id()
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_unit()
-- ========================================
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
  SELECT u.id, u.organization_id, u.name, u.description, u.created_at, u.updated_at
  FROM core.units u
  WHERE u.id = p_id
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_unit_members()
-- ========================================
-- List members of a unit
CREATE OR REPLACE FUNCTION public.list_unit_members(p_unit_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT um.user_id,
         umeta.email,
         umeta.first_name,
         umeta.last_name,
         r.name AS role
  FROM core.unit_memberships um
  JOIN core.users_meta umeta ON umeta.id = um.user_id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.unit_id = p_unit_id
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_unit_permissions()
-- ========================================
-- Returns the current user's role name and CASL rules for a given unit.
-- Used to build a unit-scoped CASL Ability in the application layer.
CREATE OR REPLACE FUNCTION public.get_user_unit_permissions(p_unit_id UUID)
RETURNS TABLE (
  role_name  TEXT,
  casl_rules JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT r.name AS role_name, r.casl_rules
  FROM core.unit_memberships um
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND um.unit_id = p_unit_id
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.create_unit()
-- ========================================
-- Create a new unit within an organization
-- RLS validates org membership; CASL controls who can create
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
) AS $$
DECLARE
  v_unit_id UUID;
BEGIN
  INSERT INTO core.units (organization_id, name, description, created_by, updated_by)
  VALUES (p_org_id, p_name, p_description, core.get_current_user_id(), core.get_current_user_id())
  RETURNING core.units.id INTO v_unit_id;

  PERFORM core.log_audit('insert', 'core.units', v_unit_id, 'create_unit', jsonb_build_object('organization_id', p_org_id, 'name', p_name));

  RETURN QUERY SELECT u.id, u.organization_id, u.name, u.description, u.created_by, u.updated_by FROM core.units u WHERE u.id = v_unit_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.assign_user_to_unit()
-- ========================================
-- Assign a user to a unit
-- RLS validates org membership; CASL controls who can assign
CREATE OR REPLACE FUNCTION public.assign_user_to_unit(p_user_id UUID, p_unit_id UUID, p_role_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (p_user_id, p_unit_id, p_role_id, core.get_current_user_id());

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'assign_user_to_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_user_from_unit()
-- ========================================
-- Remove a user from a unit (soft delete)
-- RLS validates org membership; CASL controls who can remove
CREATE OR REPLACE FUNCTION public.remove_user_from_unit(p_user_id UUID, p_unit_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.unit_memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_user_from_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_units()
-- ========================================
-- List all active units for an organization (for org members)
-- Different from list_my_units() which only shows units the caller belongs to
CREATE OR REPLACE FUNCTION public.list_units(p_org_id UUID)
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
  SELECT u.id, u.organization_id, u.name, u.description, u.created_at, u.updated_at
  FROM core.units u
  WHERE u.organization_id = p_org_id
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_unit()
-- ========================================
CREATE OR REPLACE FUNCTION public.update_unit(
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
    RAISE EXCEPTION 'Unit id is required';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Unit name is required';
  END IF;

  -- NULL p_description explicitly clears the description (matches update_organization convention)
  UPDATE core.units u
  SET name = p_name,
      description = p_description,
      updated_by = core.get_current_user_id()
  WHERE u.id = p_id
    AND u.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unit not found';
  END IF;

  PERFORM core.log_audit('update', 'core.units', p_id, 'update_unit',
    jsonb_build_object('name', p_name, 'description', p_description));

  RETURN QUERY
  SELECT u.id, u.name, u.description, u.updated_at
  FROM core.units u WHERE u.id = p_id AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_unit()
-- ========================================
CREATE OR REPLACE FUNCTION public.delete_unit(p_id UUID)
RETURNS VOID AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Unit id is required';
  END IF;

  UPDATE core.unit_memberships
  SET is_deleted = true, deleted_at = now(), deleted_by = core.get_current_user_id(), updated_by = core.get_current_user_id()
  WHERE unit_id = p_id AND is_deleted = false;

  UPDATE core.unit_meta
  SET is_deleted = true, deleted_at = now(), deleted_by = core.get_current_user_id(), updated_by = core.get_current_user_id()
  WHERE id = p_id AND is_deleted = false;

  UPDATE core.units u
  SET is_deleted = true, deleted_at = now(), deleted_by = core.get_current_user_id(), updated_by = core.get_current_user_id()
  WHERE u.id = p_id AND u.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unit not found';
  END IF;

  PERFORM core.log_audit('delete', 'core.units', p_id, 'delete_unit', '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core;

-- ========================================
-- FUNCTION: public.add_member_to_unit()
-- ========================================
-- Add an existing org member to a unit by UUID and role
-- Caller must be org super_admin
CREATE OR REPLACE FUNCTION public.add_member_to_unit(
  p_unit_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_org_id UUID;
BEGIN
  v_org_id := core.get_org_id_for_unit(p_unit_id);

  IF NOT core.is_super_admin(v_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can add members to a unit';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM core.users_meta WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = p_user_id
      AND organization_id = v_org_id
      AND is_deleted = false
  ) THEN
    RAISE EXCEPTION 'User is not a member of the organization';
  END IF;

  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
  VALUES (p_user_id, p_unit_id, p_role_id, core.get_current_user_id(), core.get_current_user_id())
  ON CONFLICT (user_id, unit_id) DO UPDATE
    SET role_id = EXCLUDED.role_id,
        is_deleted = false,
        deleted_at = NULL,
        deleted_by = NULL,
        updated_by = core.get_current_user_id(),
        updated_at = now();

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'add_member_to_unit',
    jsonb_build_object('unit_id', p_unit_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core;

-- ========================================
-- FUNCTION: public.update_unit_member_role()
-- ========================================
-- Update an existing unit member's role
-- Caller must be org super_admin
CREATE OR REPLACE FUNCTION public.update_unit_member_role(
  p_unit_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_org_id UUID;
BEGIN
  v_org_id := core.get_org_id_for_unit(p_unit_id);

  IF NOT core.is_super_admin(v_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update unit member roles';
  END IF;

  UPDATE core.unit_memberships
  SET role_id = p_role_id,
      updated_by = core.get_current_user_id(),
      updated_at = now()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found in unit';
  END IF;

  PERFORM core.log_audit('update', 'core.unit_memberships', p_user_id, 'update_unit_member_role',
    jsonb_build_object('unit_id', p_unit_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_member_from_unit()
-- ========================================
-- Soft-delete a member from a unit
-- Caller must be org super_admin
CREATE OR REPLACE FUNCTION public.remove_member_from_unit(
  p_unit_id UUID,
  p_user_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_org_id UUID;
BEGIN
  v_org_id := core.get_org_id_for_unit(p_unit_id);

  IF NOT core.is_super_admin(v_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can remove members from a unit';
  END IF;

  UPDATE core.unit_memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_member_from_unit',
    jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core;
