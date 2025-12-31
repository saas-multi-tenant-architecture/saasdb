-- 03_transfer_super_admin.sql
-- Purpose: Verify transfer_super_admin function works correctly

BEGIN;

SELECT plan(9);

-- ========================================
-- TEST: Initial state - Maria is super_admin
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  'Before transfer: Maria should be super_admin'
);

SELECT ok(
  NOT (SELECT is_super_admin FROM core.memberships
       WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
         AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
         AND is_deleted = false),
  'Before transfer: Carlos should NOT be super_admin'
);

-- ========================================
-- TEST: Only super_admin can transfer (set auth as Maria)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    'SELECT public.transfer_super_admin(%L, %L)',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Super_admin should be able to transfer ownership'
);

-- ========================================
-- TEST: After transfer - Carlos is now super_admin
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  'After transfer: Carlos should be super_admin'
);

SELECT ok(
  NOT (SELECT is_super_admin FROM core.memberships
       WHERE user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
         AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
         AND is_deleted = false),
  'After transfer: Maria should NOT be super_admin'
);

-- ========================================
-- TEST: Non-super_admin cannot transfer
-- ========================================
-- Try to transfer as Maria (no longer super_admin)
SELECT throws_ok(
  format(
    'SELECT public.transfer_super_admin(%L, %L)',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    test_helpers.get_test_user_id('sofia@test.bellaitalia.com')
  ),
  'Only the current super_admin can transfer ownership',
  'Non-super_admin should not be able to transfer ownership'
);

-- ========================================
-- TEST: Cannot transfer to non-member
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com')); -- Carlos is now super_admin

-- Luigi is member of Pizza Palace, not Bella Italia
SELECT throws_ok(
  format(
    'SELECT public.transfer_super_admin(%L, %L)',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
  ),
  'Target user is not a member of this organization',
  'Cannot transfer to user not in organization'
);

-- ========================================
-- TEST: Cannot transfer to yourself
-- ========================================
SELECT throws_ok(
  format(
    'SELECT public.transfer_super_admin(%L, %L)',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Cannot transfer super_admin to yourself',
  'Cannot transfer to yourself'
);

-- ========================================
-- TEST: Cannot transfer to deleted member
-- ========================================
-- First soft-delete Taylor's membership
UPDATE core.memberships
SET is_deleted = true, deleted_at = now()
WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT throws_ok(
  format(
    'SELECT public.transfer_super_admin(%L, %L)',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'Target user is not a member of this organization',
  'Cannot transfer to deleted member'
);

SELECT * FROM finish();

ROLLBACK;
