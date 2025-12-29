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
  WHERE um.user_id = auth.uid()
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
         u.email,
         umeta.first_name,
         umeta.last_name,
         r.name AS role
  FROM core.unit_memberships um
  JOIN auth.users u ON u.id = um.user_id
  JOIN core.users_meta umeta ON umeta.id = um.user_id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.unit_id = p_unit_id
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
  VALUES (p_org_id, p_name, p_description, auth.uid(), auth.uid())
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
  VALUES (p_user_id, p_unit_id, p_role_id, auth.uid());

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
      deleted_by = auth.uid()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_user_from_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
