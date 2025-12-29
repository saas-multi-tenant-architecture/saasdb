-- 07_invitations_rls.sql
-- Purpose: Verify RLS policies on core.invitations table

BEGIN;

SELECT plan(10);

-- ========================================
-- SETUP: Create test invitations
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria (Bella Italia)

DO $$
DECLARE
  v_result RECORD;
BEGIN
  -- Bella Italia invitation
  SELECT * INTO v_result FROM public.create_invitation(
    'bellainvite@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.bella_invitation_id', v_result.id::text, false);
END $$;

SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi (Pizza Palace)

DO $$
DECLARE
  v_result RECORD;
BEGIN
  -- Pizza Palace invitation
  SELECT * INTO v_result FROM public.create_invitation(
    'pizzainvite@example.com',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.pizza_invitation_id', v_result.id::text, false);
END $$;

-- ========================================
-- TEST: Org member can SELECT invitations for their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.invitations
    WHERE id = current_setting('test.bella_invitation_id')::uuid
  ),
  'Maria can SELECT Bella Italia invitation'
);

-- ========================================
-- TEST: Org member cannot SELECT other org's invitations
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.invitations
    WHERE id = current_setting('test.pizza_invitation_id')::uuid
  ),
  'Maria cannot SELECT Pizza Palace invitation'
);

-- ========================================
-- TEST: Luigi can SELECT Pizza Palace invitations
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.invitations
    WHERE id = current_setting('test.pizza_invitation_id')::uuid
  ),
  'Luigi can SELECT Pizza Palace invitation'
);

-- ========================================
-- TEST: Luigi cannot SELECT Bella Italia invitations
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.invitations
    WHERE id = current_setting('test.bella_invitation_id')::uuid
  ),
  'Luigi cannot SELECT Bella Italia invitation'
);

-- ========================================
-- TEST: Invitee can view their own pending invitation
-- ========================================
DO $$
DECLARE
  v_invitee_id UUID;
BEGIN
  -- Create user matching the invitation email
  v_invitee_id := test_helpers.create_test_user('bellainvite@example.com', 'Bella', 'Invitee');
  PERFORM set_config('test.invitee_id', v_invitee_id::text, false);
END $$;

SELECT utils.set_auth_user(current_setting('test.invitee_id')::uuid);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.invitations
    WHERE email = 'bellainvite@example.com'
      AND status = 'pending'
  ),
  'Invitee can view their own pending invitation'
);

-- ========================================
-- TEST: Count visible invitations per user
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT is(
  (SELECT COUNT(*)::int FROM core.invitations
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  (SELECT COUNT(*)::int FROM public.list_invitations('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)),
  'RLS allows Maria to see all Bella Italia invitations'
);

SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM core.invitations
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
     AND is_deleted = false),
  (SELECT COUNT(*)::int FROM public.list_invitations('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid)),
  'RLS allows Luigi to see all Pizza Palace invitations'
);

-- ========================================
-- TEST: Soft-deleted invitations are not visible
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

UPDATE core.invitations
SET is_deleted = true,
    deleted_at = now(),
    deleted_by = '11111111-1111-1111-1111-111111111101'
WHERE id = current_setting('test.bella_invitation_id')::uuid;

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.invitations
    WHERE id = current_setting('test.bella_invitation_id')::uuid
  ),
  'Soft-deleted invitation is not visible'
);

-- Restore for further tests
UPDATE core.invitations
SET is_deleted = false,
    deleted_at = NULL,
    deleted_by = NULL
WHERE id = current_setting('test.bella_invitation_id')::uuid;

-- ========================================
-- TEST: Org member can UPDATE invitations (for cancel/resend)
-- ========================================
SELECT lives_ok(
  format($$UPDATE core.invitations SET status = 'cancelled' WHERE id = '%s'::uuid$$,
    current_setting('test.bella_invitation_id')),
  'Org member can UPDATE invitation status'
);

-- ========================================
-- TEST: Cross-org isolation maintained
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM core.invitations),
  (SELECT COUNT(*)::int FROM core.invitations
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Maria can only see Bella Italia invitations'
);

SELECT * FROM finish();

ROLLBACK;
