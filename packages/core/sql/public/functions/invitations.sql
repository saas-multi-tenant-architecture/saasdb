-- invitations.sql
-- Purpose: Public RPC functions for invitation management
-- These are thin wrappers around core.* functions for client access

-- ========================================
-- FUNCTION: public.create_invitation()
-- ========================================
-- Creates a new invitation to join an organization or unit
--
-- Parameters:
--   p_email: Email address of the person to invite
--   p_organization_id: Organization to invite them to
--   p_role_id: Role they will have in the organization
--   p_unit_id: (Optional) Specific unit within the organization
--   p_metadata: (Optional) Additional context for the invitation
--
-- Returns: Invitation details including token (for email delivery)
--
-- Authorization: Must be a member of the organization
--   - CASL controls which roles can invite (e.g., only managers and admins)
--   - Database enforces membership requirement only
--
-- Example:
--   SELECT * FROM public.create_invitation(
--     'newuser@example.com',
--     'org-uuid',
--     'role-uuid',
--     NULL,
--     '{"message": "Welcome to the team!"}'::jsonb
--   );
CREATE OR REPLACE FUNCTION public.create_invitation(
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
BEGIN
  RETURN QUERY
  SELECT * FROM core.create_invitation(
    p_email,
    p_organization_id,
    p_role_id,
    p_unit_id,
    p_metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.accept_invitation()
-- ========================================
-- Accepts an invitation and creates organization/unit membership
--
-- Parameters:
--   p_token: The invitation token from the invite link
--
-- Returns: Organization details after successful acceptance
--
-- Authorization: Must be authenticated and email must match invitation
--
-- Example:
--   SELECT * FROM public.accept_invitation('invitation-token-here');
CREATE OR REPLACE FUNCTION public.accept_invitation(
  p_token TEXT
) RETURNS TABLE (
  organization_id UUID,
  unit_id UUID,
  role_id UUID,
  organization_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.accept_invitation(p_token);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.cancel_invitation()
-- ========================================
-- Cancels a pending invitation
--
-- Parameters:
--   p_invitation_id: ID of the invitation to cancel
--
-- Authorization: Must be the inviter or org member
--   - CASL controls which roles can cancel (e.g., only who invited or admins)
--
-- Example:
--   SELECT public.cancel_invitation('invitation-uuid');
CREATE OR REPLACE FUNCTION public.cancel_invitation(
  p_invitation_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM core.cancel_invitation(p_invitation_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.resend_invitation()
-- ========================================
-- Resends an invitation with a new token and extended expiration
--
-- Parameters:
--   p_invitation_id: ID of the invitation to resend
--
-- Returns: New invitation details including new token
--
-- Authorization: Must be a member of the organization
--   - CASL controls which roles can resend invitations
--
-- Example:
--   SELECT * FROM public.resend_invitation('invitation-uuid');
CREATE OR REPLACE FUNCTION public.resend_invitation(
  p_invitation_id UUID
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.resend_invitation(p_invitation_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_invitations()
-- ========================================
-- Lists invitations for an organization
--
-- Parameters:
--   p_organization_id: Organization to list invitations for
--   p_status: (Optional) Filter by status ('pending', 'accepted', 'expired', 'cancelled')
--
-- Returns: Table of invitation records
--
-- Authorization: Must be a member of the organization
--
-- Examples:
--   -- List all invitations
--   SELECT * FROM public.list_invitations('org-uuid');
--
--   -- List only pending invitations
--   SELECT * FROM public.list_invitations('org-uuid', 'pending');
CREATE OR REPLACE FUNCTION public.list_invitations(
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
  RETURN QUERY
  SELECT * FROM core.list_organization_invitations(p_organization_id, p_status);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_invitation_details()
-- ========================================
-- Retrieves invitation details by token (for landing page display)
-- Does not require authentication - safe for public access
--
-- Parameters:
--   p_token: The invitation token from the invite link
--
-- Returns: Invitation details (no sensitive information)
--
-- Authorization: None required (public endpoint)
--
-- Use case: Display "You've been invited to join X as Y" before signup/login
--
-- Example:
--   SELECT * FROM public.get_invitation_details('invitation-token');
CREATE OR REPLACE FUNCTION public.get_invitation_details(
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
  SELECT * FROM core.get_invitation_by_token(p_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core;

-- ========================================
-- NOTES
-- ========================================
-- These public functions are exposed as database RPCs (e.g. via PostgREST or any
-- client that calls SQL functions):
--
--   -- Create invitation -> returns { id, token, email, expires_at }
--   SELECT public.create_invitation('user@example.com', '<org-uuid>', '<role-uuid>');
--   -- Send email with link: https://app.com/invite?token={token}
--
--   -- Get invitation details (before auth)
--   SELECT public.get_invitation_details('<token-from-url>');
--
--   -- Accept invitation (after auth) -> user is now a member
--   SELECT public.accept_invitation('<token-from-url>');
--
--   -- List invitations
--   SELECT public.list_invitations('<org-uuid>', 'pending');
--
-- Security:
--   - Authorization enforced in core.* functions
--   - CASL controls role-based permissions in the application layer
--   - Tokens are cryptographically secure (32 random bytes)
--   - Emails are validated and normalized (lowercase)
--   - No sensitive data exposed in public endpoints
