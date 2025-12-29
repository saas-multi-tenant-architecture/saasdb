-- 02_super_admin_protection.sql
-- Purpose: Verify super_admin protection mechanisms work correctly

BEGIN;

SELECT plan(6);

-- ========================================
-- TEST: Cannot hard-delete super_admin membership
-- ========================================
SELECT throws_ok(
  $$DELETE FROM core.memberships
    WHERE user_id = '11111111-1111-1111-1111-111111111101'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Cannot delete super_admin membership. Transfer super_admin status first.',
  'Hard delete of super_admin membership should be blocked'
);

-- ========================================
-- TEST: Cannot soft-delete super_admin membership
-- ========================================
SELECT throws_ok(
  $$UPDATE core.memberships
    SET is_deleted = true, deleted_at = now()
    WHERE user_id = '11111111-1111-1111-1111-111111111101'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Cannot soft-delete super_admin membership. Transfer super_admin status first.',
  'Soft delete of super_admin membership should be blocked'
);

-- ========================================
-- TEST: Only one super_admin per organization (unique index)
-- ========================================
-- Try to set Carlos as super_admin (should fail due to unique index)
SELECT throws_ok(
  $$UPDATE core.memberships
    SET is_super_admin = true
    WHERE user_id = '11111111-1111-1111-1111-111111111102'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  '23505', -- unique_violation error code
  'Setting second super_admin should violate unique constraint'
);

-- ========================================
-- TEST: Super_admin status is correctly set for Maria
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111101'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  'Maria should be super_admin of Bella Italia'
);

-- ========================================
-- TEST: Non-super_admin members exist
-- ========================================
SELECT ok(
  NOT (SELECT is_super_admin FROM core.memberships
       WHERE user_id = '11111111-1111-1111-1111-111111111102'
         AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
         AND is_deleted = false),
  'Carlos should NOT be super_admin of Bella Italia'
);

-- ========================================
-- TEST: Can delete non-super_admin membership
-- ========================================
-- Create a temporary membership to delete
INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
VALUES (
  '11111111-1111-1111-1111-111111111107', -- Taylor
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000003', -- team role
  false,
  '11111111-1111-1111-1111-111111111101',
  '11111111-1111-1111-1111-111111111101'
);

SELECT lives_ok(
  $$UPDATE core.memberships
    SET is_deleted = true, deleted_at = now()
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Soft delete of non-super_admin membership should succeed'
);

SELECT * FROM finish();

ROLLBACK;
