-- 03_manage_invitations.sql
-- Purpose: Test invitation management (cancel, resend, list)

BEGIN;

SELECT plan(14);

-- ========================================
-- SETUP: Create test invitations
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_result RECORD;
BEGIN
  -- Create invitation to cancel
  SELECT * INTO v_result FROM public.create_invitation(
    'tocancel@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.cancel_invitation_id', v_result.id::text, false);

  -- Create invitation to resend
  SELECT * INTO v_result FROM public.create_invitation(
    'toresend@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.resend_invitation_id', v_result.id::text, false);
  PERFORM set_config('test.original_token', v_result.token, false);
END $$;

-- ========================================
-- TEST: Can cancel pending invitation
-- ========================================
SELECT lives_ok(
  format($$SELECT public.cancel_invitation('%s'::uuid)$$, current_setting('test.cancel_invitation_id')),
  'Can cancel pending invitation'
);

-- ========================================
-- TEST: Cancelled invitation status updated
-- ========================================
SELECT is(
  (SELECT status FROM core.invitations WHERE id = current_setting('test.cancel_invitation_id')::uuid),
  'cancelled',
  'Invitation status is cancelled'
);

-- ========================================
-- TEST: Cannot cancel already cancelled invitation
-- ========================================
SELECT throws_ok(
  format($$SELECT public.cancel_invitation('%s'::uuid)$$, current_setting('test.cancel_invitation_id')),
  'Can only cancel pending invitations',
  'Cannot cancel already cancelled invitation'
);

-- ========================================
-- TEST: Can resend pending invitation
-- ========================================
SELECT lives_ok(
  format($$SELECT * FROM public.resend_invitation('%s'::uuid)$$, current_setting('test.resend_invitation_id')),
  'Can resend pending invitation'
);

-- ========================================
-- TEST: Resend generates new token
-- ========================================
SELECT isnt(
  (SELECT token FROM core.invitations WHERE id = current_setting('test.resend_invitation_id')::uuid),
  current_setting('test.original_token'),
  'Resend generates new token'
);

-- ========================================
-- TEST: Resend extends expiration
-- ========================================
SELECT ok(
  (SELECT expires_at > now() + INTERVAL '6 days'
   FROM core.invitations
   WHERE id = current_setting('test.resend_invitation_id')::uuid),
  'Resend extends expiration date'
);

-- ========================================
-- TEST: Can resend expired invitation
-- ========================================
DO $$
DECLARE
  v_result RECORD;
  v_invitation_id UUID;
BEGIN
  SELECT * INTO v_result FROM public.create_invitation(
    'resendexpired@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  v_invitation_id := v_result.id;

  -- Manually expire it
  UPDATE core.invitations
  SET status = 'expired',
      expires_at = now() - INTERVAL '1 day'
  WHERE id = v_invitation_id;

  PERFORM set_config('test.expired_invitation_id', v_invitation_id::text, false);
END $$;

SELECT lives_ok(
  format($$SELECT * FROM public.resend_invitation('%s'::uuid)$$, current_setting('test.expired_invitation_id')),
  'Can resend expired invitation'
);

SELECT is(
  (SELECT status FROM core.invitations WHERE id = current_setting('test.expired_invitation_id')::uuid),
  'pending',
  'Resent expired invitation status is pending'
);

-- ========================================
-- TEST: List organization invitations
-- ========================================
SELECT ok(
  (SELECT COUNT(*) >= 3 FROM public.list_invitations('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)),
  'Can list organization invitations'
);

-- ========================================
-- TEST: List only pending invitations
-- ========================================
SELECT ok(
  (SELECT COUNT(*) >= 1 FROM public.list_invitations(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    'pending'
  )),
  'Can filter invitations by status'
);

-- ========================================
-- TEST: Non-member cannot list invitations
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT throws_ok(
  $$SELECT * FROM public.list_invitations('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)$$,
  'You are not authorized to view invitations for this organization',
  'Non-member cannot list invitations'
);

-- ========================================
-- TEST: Non-member cannot cancel invitation
-- ========================================
-- Fetch Bella Italia invitation ID as Maria (who can see it), before switching to Luigi
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_bella_invitation_id UUID;
BEGIN
  -- Get a Bella Italia invitation ID (must query as org member)
  SELECT id INTO v_bella_invitation_id
  FROM core.invitations
  WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    AND status = 'pending'
    AND is_deleted = false
  LIMIT 1;

  PERFORM set_config('test.bella_invitation_id', v_bella_invitation_id::text, false);
END $$;

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT throws_ok(
  format($$SELECT public.cancel_invitation('%s'::uuid)$$, current_setting('test.bella_invitation_id')),
  'Invitation not found',
  'Non-member cannot cancel invitation'
);

-- ========================================
-- TEST: Regular member can cancel invitation they created
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

DO $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT * INTO v_result FROM public.create_invitation(
    'carlosinvite@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid
  );
  PERFORM set_config('test.carlos_invitation_id', v_result.id::text, false);
END $$;

SELECT lives_ok(
  format($$SELECT public.cancel_invitation('%s'::uuid)$$, current_setting('test.carlos_invitation_id')),
  'Member can cancel invitation they created'
);

-- ========================================
-- TEST: Org member can cancel invitation created by another member (CASL controls this)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_result RECORD;
BEGIN
  -- Carlos creates invitation
  PERFORM test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));
  SELECT * INTO v_result FROM public.create_invitation(
    'cancelbyother@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid
  );
  PERFORM set_config('test.other_invitation_id', v_result.id::text, false);

  -- Switch back to Maria
  PERFORM test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));
END $$;

SELECT lives_ok(
  format($$SELECT public.cancel_invitation('%s'::uuid)$$, current_setting('test.other_invitation_id')),
  'Org member can cancel invitation created by another member (CASL controls specific permissions)'
);

SELECT * FROM finish();

ROLLBACK;
