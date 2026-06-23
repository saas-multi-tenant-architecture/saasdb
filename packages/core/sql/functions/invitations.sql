-- invitations.sql
-- Purpose: Core functions for invitation management

-- ========================================
-- FUNCTION: core.create_invitation()
-- ========================================
-- Creates a new invitation to join an organization or unit
-- Authorization: Must be a member of the organization (CASL controls role-based permissions)
CREATE OR REPLACE FUNCTION core.create_invitation(
  p_email TEXT,
  p_organization_id UUID,
  p_role_id UUID,
  p_unit_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_id UUID;
  v_invitation_id UUID;
  v_token TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Validation: User must be a member of the organization
  IF NOT core.is_org_member(p_organization_id) THEN
    RAISE EXCEPTION 'You must be a member of this organization to invite users';
  END IF;

  -- Validation: If inviting to a unit, user must be a member of that unit
  IF p_unit_id IS NOT NULL THEN
    IF NOT core.is_unit_member(p_unit_id) THEN
      RAISE EXCEPTION 'You must be a member of this unit to invite users to it';
    END IF;

    -- Ensure unit belongs to the organization
    IF NOT EXISTS (
      SELECT 1 FROM core.units u_check
      WHERE u_check.id = p_unit_id AND u_check.organization_id = p_organization_id
    ) THEN
      RAISE EXCEPTION 'Unit does not belong to this organization';
    END IF;
  END IF;

  -- Validation: Role must exist
  IF NOT EXISTS (SELECT 1 FROM core.roles r_check WHERE r_check.id = p_role_id) THEN
    RAISE EXCEPTION 'Invalid role specified';
  END IF;

  -- Validation: Cannot invite as super_admin (must use transfer function)
  IF EXISTS (
    SELECT 1 FROM core.roles r_check
    WHERE r_check.id = p_role_id AND r_check.name = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Cannot invite users as super_admin. Use public.transfer_super_admin() to transfer ownership.';
  END IF;

  -- Validation: Check for duplicate pending invitation
  IF EXISTS (
    SELECT 1 FROM core.invitations inv_check
    WHERE inv_check.email = p_email
      AND inv_check.organization_id = p_organization_id
      AND inv_check.status = 'pending'
      AND inv_check.is_deleted = false
      AND inv_check.expires_at > now()
  ) THEN
    RAISE EXCEPTION 'A pending invitation to this email already exists for this organization';
  END IF;

  -- Validation: Check if user is already a member (use users_meta —
  -- the adapter's user table is not directly accessible via SECURITY INVOKER)
  IF EXISTS (
    SELECT 1 FROM core.memberships m
    JOIN core.users_meta um ON um.id = m.user_id
    WHERE um.email = lower(p_email)
      AND m.organization_id = p_organization_id
      AND m.is_deleted = false
  ) THEN
    RAISE EXCEPTION 'This user is already a member of the organization';
  END IF;

  -- Generate secure token
  v_token := encode(gen_random_bytes(32), 'base64');
  v_expires_at := now() + INTERVAL '7 days';

  -- Create invitation
  INSERT INTO core.invitations (
    email,
    organization_id,
    unit_id,
    role_id,
    invited_by,
    token,
    expires_at,
    metadata,
    created_by
  ) VALUES (
    lower(p_email),
    p_organization_id,
    p_unit_id,
    p_role_id,
    v_caller_id,
    v_token,
    v_expires_at,
    p_metadata,
    v_caller_id
  ) RETURNING core.invitations.id INTO v_invitation_id;

  -- Log the action
  PERFORM core.log_audit(
    'create',
    'core.invitations',
    v_invitation_id,
    'create_invitation',
    jsonb_build_object(
      'email', p_email,
      'organization_id', p_organization_id,
      'unit_id', p_unit_id,
      'role_id', p_role_id
    )
  );

  -- Return invitation details (for email delivery)
  RETURN QUERY
  SELECT v_invitation_id, v_token, lower(p_email), v_expires_at;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core, extensions;

-- ========================================
-- FUNCTION: core.accept_invitation()
-- ========================================
-- Accepts an invitation and creates/updates membership
-- This is called after user authentication
CREATE OR REPLACE FUNCTION core.accept_invitation(
  p_token TEXT
) RETURNS TABLE (
  organization_id UUID,
  unit_id UUID,
  role_id UUID,
  organization_name TEXT
) AS $$
DECLARE
  v_invitation RECORD;
  v_caller_id UUID;
  v_caller_email TEXT;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Get caller's email (use users_meta — the adapter's user table is not directly accessible via SECURITY INVOKER)
  SELECT email INTO v_caller_email
  FROM core.users_meta
  WHERE id = v_caller_id;

  -- Fetch and validate invitation
  SELECT * INTO v_invitation
  FROM core.invitations
  WHERE token = p_token
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid invitation token';
  END IF;

  -- Check invitation status
  IF v_invitation.status != 'pending' THEN
    RAISE EXCEPTION 'This invitation has already been %', v_invitation.status;
  END IF;

  -- Check expiration
  IF v_invitation.expires_at < now() THEN
    -- Mark as expired
    UPDATE core.invitations
    SET status = 'expired',
        updated_at = now()
    WHERE id = v_invitation.id;

    RAISE EXCEPTION 'This invitation has expired';
  END IF;

  -- Validate email match
  IF lower(v_caller_email) != lower(v_invitation.email) THEN
    RAISE EXCEPTION 'This invitation was sent to a different email address';
  END IF;

  -- Check if already a member
  IF EXISTS (
    SELECT 1 FROM core.memberships m
    WHERE m.user_id = v_caller_id
      AND m.organization_id = v_invitation.organization_id
      AND m.is_deleted = false
  ) THEN
    RAISE EXCEPTION 'You are already a member of this organization';
  END IF;

  -- Create organization membership
  INSERT INTO core.memberships (
    user_id,
    organization_id,
    role_id,
    is_super_admin,
    created_by
  ) VALUES (
    v_caller_id,
    v_invitation.organization_id,
    v_invitation.role_id,
    false,
    v_invitation.invited_by
  );

  -- Create unit membership if specified
  IF v_invitation.unit_id IS NOT NULL THEN
    INSERT INTO core.unit_memberships (
      user_id,
      unit_id,
      role_id,
      created_by
    ) VALUES (
      v_caller_id,
      v_invitation.unit_id,
      v_invitation.role_id,
      v_invitation.invited_by
    );
  END IF;

  -- Mark invitation as accepted
  UPDATE core.invitations
  SET status = 'accepted',
      accepted_at = now(),
      accepted_by = v_caller_id,
      updated_at = now()
  WHERE id = v_invitation.id;

  -- Log the action
  PERFORM core.log_audit(
    'accept',
    'core.invitations',
    v_invitation.id,
    'accept_invitation',
    jsonb_build_object(
      'organization_id', v_invitation.organization_id,
      'user_id', v_caller_id
    )
  );

  -- Return details
  RETURN QUERY
  SELECT
    v_invitation.organization_id,
    v_invitation.unit_id,
    v_invitation.role_id,
    o.name
  FROM core.organizations o
  WHERE o.id = v_invitation.organization_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

-- ========================================
-- FUNCTION: core.cancel_invitation()
-- ========================================
-- Cancels a pending invitation
-- Authorization: Must be the inviter or an org member (CASL controls specific role requirements)
CREATE OR REPLACE FUNCTION core.cancel_invitation(
  p_invitation_id UUID
) RETURNS VOID AS $$
DECLARE
  v_invitation RECORD;
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Fetch invitation
  SELECT * INTO v_invitation
  FROM core.invitations
  WHERE id = p_invitation_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  -- Authorization: Must be the inviter or a member of the organization
  IF v_invitation.invited_by != v_caller_id AND NOT core.is_org_member(v_invitation.organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to cancel this invitation';
  END IF;

  -- Can only cancel pending invitations
  IF v_invitation.status != 'pending' THEN
    RAISE EXCEPTION 'Can only cancel pending invitations';
  END IF;

  -- Mark as cancelled
  UPDATE core.invitations
  SET status = 'cancelled',
      updated_at = now(),
      updated_by = v_caller_id
  WHERE id = p_invitation_id;

  -- Log the action
  PERFORM core.log_audit(
    'cancel',
    'core.invitations',
    p_invitation_id,
    'cancel_invitation',
    jsonb_build_object('email', v_invitation.email)
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- FUNCTION: core.resend_invitation()
-- ========================================
-- Resends an invitation with a new token and extended expiration
-- Authorization: Must be a member of the organization
CREATE OR REPLACE FUNCTION core.resend_invitation(
  p_invitation_id UUID
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
DECLARE
  v_invitation RECORD;
  v_caller_id UUID;
  v_new_token TEXT;
  v_new_expires_at TIMESTAMPTZ;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Fetch invitation
  SELECT * INTO v_invitation
  FROM core.invitations
  WHERE core.invitations.id = p_invitation_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  -- Authorization: Must be a member of the organization
  IF NOT core.is_org_member(v_invitation.organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to resend this invitation';
  END IF;

  -- Can only resend pending or expired invitations
  IF v_invitation.status NOT IN ('pending', 'expired') THEN
    RAISE EXCEPTION 'Can only resend pending or expired invitations';
  END IF;

  -- Generate new token and expiration
  v_new_token := encode(gen_random_bytes(32), 'base64');
  v_new_expires_at := now() + INTERVAL '7 days';

  -- Update invitation
  UPDATE core.invitations
  SET token = v_new_token,
      expires_at = v_new_expires_at,
      status = 'pending',
      updated_at = now(),
      updated_by = v_caller_id
  WHERE core.invitations.id = p_invitation_id;

  -- Log the action
  PERFORM core.log_audit(
    'resend',
    'core.invitations',
    p_invitation_id,
    'resend_invitation',
    jsonb_build_object('email', v_invitation.email)
  );

  -- Return new invitation details
  RETURN QUERY
  SELECT p_invitation_id, v_new_token, v_invitation.email, v_new_expires_at;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core, extensions;

-- ========================================
-- FUNCTION: core.list_organization_invitations()
-- ========================================
-- Lists invitations for an organization
-- Authorization: Must be a member of the organization
CREATE OR REPLACE FUNCTION core.list_organization_invitations(
  p_organization_id UUID,
  p_status TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_id UUID,
  unit_id UUID,
  role_name TEXT,
  invited_by_email TEXT,
  status TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Authorization: Must be a member of the organization
  IF NOT core.is_org_member(p_organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to view invitations for this organization';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.email,
    i.organization_id,
    i.unit_id,
    r.name AS role_name,
    um.email AS invited_by_email,
    i.status,
    i.expires_at,
    i.created_at
  FROM core.invitations i
  JOIN core.roles r ON r.id = i.role_id
  LEFT JOIN core.users_meta um ON um.id = i.invited_by
  WHERE i.organization_id = p_organization_id
    AND i.is_deleted = false
    AND (p_status IS NULL OR i.status = p_status)
  ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- FUNCTION: core.get_invitation_by_token()
-- ========================================
-- Retrieves invitation details by token (for landing page display)
-- This is public-safe - does not require authentication
CREATE OR REPLACE FUNCTION core.get_invitation_by_token(
  p_token TEXT
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_name TEXT,
  unit_name TEXT,
  role_name TEXT,
  invited_by_name TEXT,
  expires_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.email,
    o.name AS organization_name,
    u.name AS unit_name,
    r.name AS role_name,
    COALESCE(um.first_name || ' ' || um.last_name, um.email) AS invited_by_name,
    i.expires_at,
    i.status
  FROM core.invitations i
  JOIN core.organizations o ON o.id = i.organization_id
  LEFT JOIN core.units u ON u.id = i.unit_id
  JOIN core.roles r ON r.id = i.role_id
  LEFT JOIN core.users_meta um ON um.id = i.invited_by
  WHERE i.token = p_token
    AND i.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- FUNCTION: core.expire_old_invitations()
-- ========================================
-- Utility function to mark expired invitations
-- Should be called periodically (via cron or before checking invitations)
CREATE OR REPLACE FUNCTION core.expire_old_invitations()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE core.invitations
  SET status = 'expired',
      updated_at = now()
  WHERE status = 'pending'
    AND expires_at < now()
    AND is_deleted = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- NOTES
-- ========================================
-- Authorization model:
--   - create_invitation: Must be org member (CASL controls role permissions)
--   - accept_invitation: Authenticated user matching invitation email
--   - cancel_invitation: Inviter or org member (CASL controls role permissions)
--   - resend_invitation: Org member (CASL controls role permissions)
--   - list_invitations: Org member
--   - get_invitation_by_token: Public (no auth required)
--
-- Token security:
--   - 32-byte random tokens, base64 encoded
--   - Tokens are unique and indexed for fast lookup
--   - Tokens expire after 7 days
--
-- Edge cases handled:
--   - Duplicate pending invitations prevented
--   - Email validation on acceptance
--   - Expired invitation detection
--   - Already-a-member detection
--   - Cannot invite as super_admin
