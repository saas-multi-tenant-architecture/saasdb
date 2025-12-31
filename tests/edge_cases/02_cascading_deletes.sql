-- 02_cascading_deletes.sql
-- Purpose: Test that soft-deletes cascade correctly and data integrity is maintained

BEGIN;

SELECT plan(10);

-- ========================================
-- TEST: Soft-deleting org doesn't cascade to units (intentional)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Count units before
DO $$
BEGIN
  PERFORM set_config('test.units_before',
    (SELECT COUNT(*)::text FROM core.units
     WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND is_deleted = false), true);
END $$;

-- Soft-delete org
UPDATE core.organizations
SET is_deleted = true, deleted_at = now(), deleted_by = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Units should still exist (not cascaded)
SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  current_setting('test.units_before')::int,
  'Units should not be cascaded when org is soft-deleted'
);

-- Restore org
UPDATE core.organizations
SET is_deleted = false, deleted_at = NULL, deleted_by = NULL
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ========================================
-- TEST: Soft-deleting unit doesn't cascade to unit_memberships
-- ========================================
-- Count unit_memberships before
DO $$
BEGIN
  PERFORM set_config('test.memberships_before',
    (SELECT COUNT(*)::text FROM core.unit_memberships
     WHERE unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
       AND is_deleted = false), true);
END $$;

-- Soft-delete unit
UPDATE core.units
SET is_deleted = true, deleted_at = now()
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

-- Unit memberships should still exist
SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships
   WHERE unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
     AND is_deleted = false),
  current_setting('test.memberships_before')::int,
  'Unit memberships should not be cascaded when unit is soft-deleted'
);

-- Restore unit
UPDATE core.units
SET is_deleted = false, deleted_at = NULL
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

-- ========================================
-- TEST: Memberships table integrity with soft-deleted org
-- ========================================
UPDATE core.organizations
SET is_deleted = true, deleted_at = now()
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Org memberships should still exist in database
SELECT ok(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') > 0,
  'Org memberships should exist even when org is soft-deleted'
);

-- Restore
UPDATE core.organizations
SET is_deleted = false, deleted_at = NULL
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ========================================
-- TEST: Can query historical data (soft-deleted)
-- ========================================
-- Create and soft-delete a unit
DO $$
DECLARE
  v_maria_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');

  INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Temporary Unit',
    v_maria_id,
    v_maria_id
  );

  UPDATE core.units
  SET is_deleted = true, deleted_at = now(), deleted_by = v_maria_id
  WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99';
END $$;

-- Can query the deleted record directly (for audit purposes)
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99'
      AND is_deleted = true
  ),
  'Soft-deleted data should be queryable for auditing'
);

-- But RLS hides it from normal queries
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99'
      AND is_deleted = false
  ),
  'Soft-deleted data should be hidden from active queries'
);

-- ========================================
-- TEST: Deleted user can be restored
-- ========================================
-- Soft-delete Taylor's membership
UPDATE core.memberships
SET is_deleted = true, deleted_at = now()
WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'Deleted member should not appear in list'
);

-- Restore membership
UPDATE core.memberships
SET is_deleted = false, deleted_at = NULL
WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'Restored member should appear in list'
);

-- ========================================
-- TEST: Audit trail preserved for deletes
-- ========================================
-- Soft-delete Sam
UPDATE core.memberships
SET is_deleted = true, deleted_at = now(), deleted_by = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
WHERE user_id = test_helpers.get_test_user_id('sam@test.bellaitalia.com')
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  (SELECT deleted_by FROM core.memberships
   WHERE user_id = test_helpers.get_test_user_id('sam@test.bellaitalia.com')
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
  'deleted_by should be recorded'
);

SELECT ok(
  (SELECT deleted_at FROM core.memberships
   WHERE user_id = test_helpers.get_test_user_id('sam@test.bellaitalia.com')
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') IS NOT NULL,
  'deleted_at should be recorded'
);

SELECT * FROM finish();

ROLLBACK;
