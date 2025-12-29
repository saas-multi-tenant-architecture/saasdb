-- 03_transfer_super_admin.sql
-- Purpose: Verify transfer_super_admin function works correctly

BEGIN;

SELECT plan(10);

-- ========================================
-- TEST: Initial state - Maria is super_admin
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111101'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  'Before transfer: Maria should be super_admin'
);

SELECT ok(
  NOT (SELECT is_super_admin FROM core.memberships
       WHERE user_id = '11111111-1111-1111-1111-111111111102'
         AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
         AND is_deleted = false),
  'Before transfer: Carlos should NOT be super_admin'
);

-- ========================================
-- TEST: Only super_admin can transfer (set auth as Maria)
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101');

SELECT lives_ok(
  $$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111102'
  )$$,
  'Super_admin should be able to transfer ownership'
);

-- ========================================
-- TEST: After transfer - Carlos is now super_admin
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111102'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  'After transfer: Carlos should be super_admin'
);

SELECT ok(
  NOT (SELECT is_super_admin FROM core.memberships
       WHERE user_id = '11111111-1111-1111-1111-111111111101'
         AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
         AND is_deleted = false),
  'After transfer: Maria should NOT be super_admin'
);

-- ========================================
-- TEST: Non-super_admin cannot transfer
-- ========================================
-- Try to transfer as Maria (no longer super_admin)
SELECT throws_ok(
  $$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111103'
  )$$,
  'Only the current super_admin can transfer ownership',
  'Non-super_admin should not be able to transfer ownership'
);

-- ========================================
-- TEST: Cannot transfer to non-member
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos is now super_admin

-- Luigi is member of Pizza Palace, not Bella Italia
SELECT throws_ok(
  $$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111201'
  )$$,
  'Target user must be an active member of the organization',
  'Cannot transfer to user not in organization'
);

-- ========================================
-- TEST: Cannot transfer to yourself
-- ========================================
SELECT throws_ok(
  $$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111102'
  )$$,
  'Cannot transfer super_admin status to yourself',
  'Cannot transfer to yourself'
);

-- ========================================
-- TEST: Cannot transfer to deleted member
-- ========================================
-- First soft-delete Taylor's membership (if exists)
UPDATE core.memberships
SET is_deleted = true, deleted_at = now()
WHERE user_id = '11111111-1111-1111-1111-111111111107'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Create and soft-delete a test membership
INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, is_deleted, deleted_at, created_by, updated_by)
VALUES (
  '11111111-1111-1111-1111-111111111107',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000003',
  false,
  true,
  now(),
  '11111111-1111-1111-1111-111111111102',
  '11111111-1111-1111-1111-111111111102'
);

SELECT throws_ok(
  $$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111107'
  )$$,
  'Target user must be an active member of the organization',
  'Cannot transfer to deleted member'
);

SELECT * FROM finish();

ROLLBACK;
