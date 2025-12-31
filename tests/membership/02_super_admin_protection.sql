-- 02_super_admin_protection.sql
-- Purpose: Verify super_admin protection mechanisms work correctly

BEGIN;

SELECT plan(6);

-- ========================================
-- TEST: Cannot hard-delete super_admin membership
-- ========================================
SELECT throws_ok(
  format(
    'DELETE FROM core.memberships WHERE user_id = %L AND organization_id = %L',
    test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  'Cannot delete super_admin membership. Transfer super_admin status first.',
  'Hard delete of super_admin membership should be blocked'
);

-- ========================================
-- TEST: Cannot soft-delete super_admin membership
-- ========================================
SELECT throws_ok(
  format(
    'UPDATE core.memberships SET is_deleted = true, deleted_at = now() WHERE user_id = %L AND organization_id = %L',
    test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  'Cannot soft-delete super_admin membership. Transfer super_admin status first.',
  'Soft delete of super_admin membership should be blocked'
);

-- ========================================
-- TEST: Only one super_admin per organization (unique index)
-- ========================================
-- Try to set Carlos as super_admin (should fail due to unique index)
-- Using 4-arg form: throws_ok(sql, errcode, errmsg_pattern, description)
SELECT throws_ok(
  format(
    'UPDATE core.memberships SET is_super_admin = true WHERE user_id = %L AND organization_id = %L',
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  '23505', -- unique_violation error code
  NULL,    -- don't check specific error message
  'Setting second super_admin should violate unique constraint'
);

-- ========================================
-- TEST: Super_admin status is correctly set for Maria
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  'Maria should be super_admin of Bella Italia'
);

-- ========================================
-- TEST: Non-super_admin members exist
-- ========================================
SELECT ok(
  NOT (SELECT is_super_admin FROM core.memberships
       WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
         AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
         AND is_deleted = false),
  'Carlos should NOT be super_admin of Bella Italia'
);

-- ========================================
-- TEST: Can delete non-super_admin membership
-- ========================================
-- Use Taylor who already exists in the fixtures as an org member with no unit assignments
SELECT lives_ok(
  format(
    'UPDATE core.memberships SET is_deleted = true, deleted_at = now() WHERE user_id = %L AND organization_id = %L',
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  'Soft delete of non-super_admin membership should succeed'
);

SELECT * FROM finish();

ROLLBACK;
