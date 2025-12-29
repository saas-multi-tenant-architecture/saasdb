-- 02_cascading_deletes.sql
-- Purpose: Test that soft-deletes cascade correctly and data integrity is maintained

BEGIN;

SELECT plan(10);

-- ========================================
-- TEST: Soft-deleting org doesn't cascade to units (intentional)
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

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
SET is_deleted = true, deleted_at = now(), deleted_by = '11111111-1111-1111-1111-111111111101'
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
     WHERE unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001'
       AND is_deleted = false), true);
END $$;

-- Soft-delete unit
UPDATE core.units
SET is_deleted = true, deleted_at = now()
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

-- Unit memberships should still exist
SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships
   WHERE unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001'
     AND is_deleted = false),
  current_setting('test.memberships_before')::int,
  'Unit memberships should not be cascaded when unit is soft-deleted'
);

-- Restore unit
UPDATE core.units
SET is_deleted = false, deleted_at = NULL
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

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
INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000099',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Temporary Unit',
  '11111111-1111-1111-1111-111111111101',
  '11111111-1111-1111-1111-111111111101'
);

UPDATE core.units
SET is_deleted = true, deleted_at = now(), deleted_by = '11111111-1111-1111-1111-111111111101'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000099';

-- Can query the deleted record directly (for audit purposes)
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000099'
      AND is_deleted = true
  ),
  'Soft-deleted data should be queryable for auditing'
);

-- But RLS hides it from normal queries
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000099'
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
WHERE user_id = '11111111-1111-1111-1111-111111111107'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
  ),
  'Deleted member should not appear in list'
);

-- Restore membership
UPDATE core.memberships
SET is_deleted = false, deleted_at = NULL
WHERE user_id = '11111111-1111-1111-1111-111111111107'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
  ),
  'Restored member should appear in list'
);

-- ========================================
-- TEST: Audit trail preserved for deletes
-- ========================================
-- Soft-delete Sam
UPDATE core.memberships
SET is_deleted = true, deleted_at = now(), deleted_by = '11111111-1111-1111-1111-111111111101'
WHERE user_id = '11111111-1111-1111-1111-111111111106'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  (SELECT deleted_by FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111106'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = '11111111-1111-1111-1111-111111111101'::uuid,
  'deleted_by should be recorded'
);

SELECT ok(
  (SELECT deleted_at FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111106'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') IS NOT NULL,
  'deleted_at should be recorded'
);

SELECT * FROM finish();

ROLLBACK;
