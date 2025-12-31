-- 02_accept_invitation.sql
-- Purpose: Test invitation acceptance functionality

BEGIN;

SELECT plan(12);

-- ========================================
-- SETUP: Create a test invitation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_result RECORD;
  v_token TEXT;
BEGIN
  SELECT * INTO v_result FROM public.create_invitation(
    'testaccept@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );

  -- Store token in a temp config for tests to use
  PERFORM set_config('test.invitation_token', v_result.token, false);
END $$;

-- ========================================
-- TEST: Can retrieve invitation details by token (unauthenticated)
-- ========================================
SELECT test_helpers.clear_auth_user();

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.get_invitation_details(current_setting('test.invitation_token'))
    WHERE email = 'testaccept@example.com'
      AND organization_name = 'Bella Italia'
  ),
  'Can get invitation details without authentication'
);

-- ========================================
-- TEST: Create a new user and accept invitation
-- ========================================
DO $$
DECLARE
  v_new_user_id UUID;
BEGIN
  v_new_user_id := test_helpers.create_test_user('testaccept@example.com', 'Test', 'User');
  PERFORM set_config('test.new_user_id', v_new_user_id::text, false);
END $$;

SELECT test_helpers.set_auth_user(current_setting('test.new_user_id')::uuid);

SELECT lives_ok(
  format($$SELECT * FROM public.accept_invitation('%s')$$, current_setting('test.invitation_token')),
  'New user can accept invitation'
);

-- ========================================
-- TEST: Invitation status changed to accepted
-- ========================================
SELECT is(
  (SELECT status FROM core.invitations WHERE token = current_setting('test.invitation_token')),
  'accepted',
  'Invitation status is now accepted'
);

-- ========================================
-- TEST: Membership was created
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = current_setting('test.new_user_id')::uuid
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      AND role_id = '00000000-0000-0000-0000-000000000002'
      AND is_deleted = false
  ),
  'Membership was created for user'
);

-- ========================================
-- TEST: Cannot accept invitation twice
-- ========================================
SELECT throws_ok(
  format($$SELECT * FROM public.accept_invitation('%s')$$, current_setting('test.invitation_token')),
  'This invitation has already been accepted',
  'Cannot accept invitation twice'
);

-- ========================================
-- TEST: Cannot accept with wrong email
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_wrong_token TEXT;
BEGIN
  SELECT token INTO v_wrong_token FROM public.create_invitation(
    'onlyformaria@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.wrong_email_token', v_wrong_token, false);
END $$;

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT throws_ok(
  format($$SELECT * FROM public.accept_invitation('%s')$$, current_setting('test.wrong_email_token')),
  'This invitation was sent to a different email address',
  'Cannot accept invitation sent to different email'
);

-- ========================================
-- TEST: Cannot accept expired invitation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_expired_token TEXT;
  v_invitation_id UUID;
BEGIN
  SELECT token, id INTO v_expired_token, v_invitation_id
  FROM public.create_invitation(
    'expired@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );

  -- Manually expire the invitation
  UPDATE core.invitations
  SET expires_at = now() - INTERVAL '1 day'
  WHERE id = v_invitation_id;

  PERFORM set_config('test.expired_token', v_expired_token, false);
END $$;

-- Create user for expired invitation
DO $$
DECLARE
  v_expired_user_id UUID;
BEGIN
  v_expired_user_id := test_helpers.create_test_user('expired@example.com', 'Expired', 'User');
  PERFORM set_config('test.expired_user_id', v_expired_user_id::text, false);
END $$;

SELECT test_helpers.set_auth_user(current_setting('test.expired_user_id')::uuid);

SELECT throws_ok(
  format($$SELECT * FROM public.accept_invitation('%s')$$, current_setting('test.expired_token')),
  'This invitation has expired',
  'Cannot accept expired invitation'
);

-- ========================================
-- TEST: Expired invitation is marked as expired
-- ========================================
SELECT is(
  (SELECT status FROM core.invitations WHERE token = current_setting('test.expired_token')),
  'expired',
  'Expired invitation status is updated'
);

-- ========================================
-- TEST: Cannot accept invitation if already a member
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_duplicate_token TEXT;
BEGIN
  SELECT token INTO v_duplicate_token FROM public.create_invitation(
    'maria@test.bellaitalia.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  );
  PERFORM set_config('test.duplicate_token', v_duplicate_token, false);
END $$;

SELECT throws_ok(
  format($$SELECT * FROM public.accept_invitation('%s')$$, current_setting('test.duplicate_token')),
  'You are already a member of this organization',
  'Cannot accept invitation if already a member'
);

-- ========================================
-- TEST: Invalid token returns error
-- ========================================
SELECT test_helpers.set_auth_user(current_setting('test.new_user_id')::uuid);

SELECT throws_ok(
  $$SELECT * FROM public.accept_invitation('invalid-token-12345')$$,
  'Invalid invitation token',
  'Invalid token returns error'
);

-- ========================================
-- TEST: Unit membership created for unit-specific invitation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Maria needs to be a unit member of Mall first (she's not in Mall by default)
DO $$
DECLARE
  v_maria_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (
    v_maria_id,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03', -- Mall unit
    '00000000-0000-0000-0000-000000000001',
    v_maria_id
  );
END $$;

DO $$
DECLARE
  v_unit_token TEXT;
  v_unit_user_id UUID;
BEGIN
  SELECT token INTO v_unit_token FROM public.create_invitation(
    'unitinvite@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid -- Mall unit
  );

  v_unit_user_id := test_helpers.create_test_user('unitinvite@example.com', 'Unit', 'User');

  PERFORM set_config('test.unit_token', v_unit_token, false);
  PERFORM set_config('test.unit_user_id', v_unit_user_id::text, false);
END $$;

SELECT test_helpers.set_auth_user(current_setting('test.unit_user_id')::uuid);

SELECT lives_ok(
  format($$SELECT * FROM public.accept_invitation('%s')$$, current_setting('test.unit_token')),
  'Can accept unit-specific invitation'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = current_setting('test.unit_user_id')::uuid
      AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'
      AND is_deleted = false
  ),
  'Unit membership created for unit invitation'
);

SELECT * FROM finish();

ROLLBACK;
