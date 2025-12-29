-- 04_organization_membership.sql
-- Purpose: Verify organization membership functions work correctly

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql
\i tests/fixtures/04_pizza_palace.sql

SELECT plan(12);

-- ========================================
-- TEST: list_organization_members returns correct data
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

-- Count Bella Italia members (should be 7: Maria, Carlos, Sofia, Alex, Jordan, Sam, Taylor)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  7,
  'Bella Italia should have 7 active members'
);

-- ========================================
-- TEST: list_organization_members includes is_super_admin field
-- ========================================
SELECT ok(
  (SELECT is_super_admin FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = '11111111-1111-1111-1111-111111111101'),
  'Maria should show as super_admin in member list'
);

SELECT ok(
  NOT (SELECT is_super_admin FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
       WHERE user_id = '11111111-1111-1111-1111-111111111102'),
  'Carlos should NOT show as super_admin in member list'
);

-- ========================================
-- TEST: list_organization_members shows correct roles
-- ========================================
SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = '11111111-1111-1111-1111-111111111101'),
  'super_admin',
  'Maria should have super_admin role'
);

SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = '11111111-1111-1111-1111-111111111102'),
  'manager',
  'Carlos should have manager role'
);

-- ========================================
-- TEST: Organization isolation - Pizza Palace members
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM public.list_organization_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')),
  2,
  'Pizza Palace should have 2 active members'
);

-- ========================================
-- TEST: Cannot see other organization members
-- ========================================
-- Luigi trying to list Bella Italia members
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  0,
  'Luigi should not see Bella Italia members (different org)'
);

-- ========================================
-- TEST: Soft-deleted members not listed
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

-- Soft-delete Taylor's membership
UPDATE core.memberships
SET is_deleted = true, deleted_at = now(), deleted_by = '11111111-1111-1111-1111-111111111101'
WHERE user_id = '11111111-1111-1111-1111-111111111107'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT is(
  (SELECT COUNT(*)::int FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  6,
  'After soft-delete, Bella Italia should have 6 active members'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
  ),
  'Taylor should not appear in member list after soft-delete'
);

-- ========================================
-- TEST: is_org_member helper function
-- ========================================
SELECT ok(
  core.is_org_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Maria should be detected as org member'
);

SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT ok(
  NOT core.is_org_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Luigi should NOT be detected as Bella Italia member'
);

SELECT * FROM finish();

ROLLBACK;
