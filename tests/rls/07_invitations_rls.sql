-- 07_invitations_rls.sql
-- Purpose: Verify RLS policies on core.invitations table

BEGIN;

SELECT plan(11);

-- ========================================
-- SETUP: Create test invitations
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

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

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

DO $$
DECLARE
  v_result RECORD;
BEGIN
  -- Pizza Palace invitation
  SELECT * INTO v_result FROM public.create_invitation(
    'pizzainvite@example.com',
    'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.pizza_invitation_id', v_result.id::text, false);
END $$;

-- ========================================
-- TEST: Org member can SELECT invitations for their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

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
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

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

SELECT test_helpers.set_auth_user(current_setting('test.invitee_id')::uuid);

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
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.invitations
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  (SELECT COUNT(*)::int FROM public.list_invitations('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)),
  'RLS allows Maria to see all Bella Italia invitations'
);

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.invitations
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
     AND is_deleted = false),
  (SELECT COUNT(*)::int FROM public.list_invitations('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid)),
  'RLS allows Luigi to see all Pizza Palace invitations'
);

-- ========================================
-- TEST: Cancelled invitation is visible to org member but not to invitee
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT public.cancel_invitation(current_setting('test.bella_invitation_id')::uuid);

-- Org member can still see cancelled invitations
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.invitations
    WHERE id = current_setting('test.bella_invitation_id')::uuid
      AND status = 'cancelled'
  ),
  'Cancelled invitation still visible to org member'
);

-- Invitee can no longer see the cancelled invitation (status is not pending)
SELECT test_helpers.set_auth_user(current_setting('test.invitee_id')::uuid);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.invitations
    WHERE email = 'bellainvite@example.com'
      AND status = 'pending'
  ),
  'Cancelled invitation not visible to invitee (status not pending)'
);

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

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
