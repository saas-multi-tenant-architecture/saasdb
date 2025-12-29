-- invitations.sql
-- Purpose: RLS policies for core.invitations table
--
-- Policy Philosophy:
-- - Invitations are managed through functions (create, accept, cancel, resend)
-- - RLS ensures users can only see invitations for organizations they belong to
-- - The invitee (by email) can view their own pending invitations
-- - No direct INSERT/UPDATE/DELETE - all operations via functions

-- ========================================
-- ENABLE RLS
-- ========================================
ALTER TABLE core.invitations ENABLE ROW LEVEL SECURITY;

-- ========================================
-- POLICY: SELECT
-- ========================================
-- Users can view invitations if:
-- 1. They are a member of the organization (to manage invitations)
-- 2. The invitation is addressed to their email (to accept invitations)
CREATE POLICY invitations_select ON core.invitations
  FOR SELECT USING (
    -- Org members can view all invitations for their org
    core.is_org_member(organization_id)
    OR
    -- Users can view invitations sent to their email
    (
      email = (SELECT email FROM auth.users WHERE id = auth.uid())
      AND status = 'pending'
      AND is_deleted = false
    )
  );

-- ========================================
-- POLICY: INSERT
-- ========================================
-- Users can create invitations if they are a member of the organization
-- Note: Additional validation (role checks, duplicate prevention) happens in core.create_invitation()
CREATE POLICY invitations_insert ON core.invitations
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id)
  );

-- ========================================
-- POLICY: UPDATE
-- ========================================
-- Users can update invitations if:
-- 1. They are a member of the organization (to cancel/resend)
-- 2. They are accepting their own invitation (email match)
CREATE POLICY invitations_update ON core.invitations
  FOR UPDATE USING (
    core.is_org_member(organization_id)
    OR
    (
      email = (SELECT email FROM auth.users WHERE id = auth.uid())
      AND status = 'pending'
    )
  )
  WITH CHECK (
    core.is_org_member(organization_id)
    OR
    (
      email = (SELECT email FROM auth.users WHERE id = auth.uid())
      AND status IN ('accepted', 'expired')  -- Can only mark as accepted or expired
    )
  );

-- ========================================
-- NO DELETE POLICY
-- ========================================
-- Hard deletes are not allowed - invitations use soft deletes (is_deleted = true)
-- This preserves the invitation audit trail
-- Default RLS behavior blocks all DELETE operations

-- ========================================
-- NOTES
-- ========================================
-- RLS provides defense-in-depth security:
--   - Functions enforce business logic (duplicate prevention, expiration, etc.)
--   - RLS ensures tenant isolation (can't see other org's invitations)
--   - CASL (application layer) controls role-based permissions
--
-- The UPDATE policy allows:
--   - Org members to update status (cancel, resend)
--   - Invitees to accept their invitation (set status = 'accepted')
--
-- Security considerations:
--   - Email matching prevents users from accepting invitations meant for others
--   - Org membership requirement prevents cross-tenant invitation manipulation
--   - Soft deletes preserve audit trail
