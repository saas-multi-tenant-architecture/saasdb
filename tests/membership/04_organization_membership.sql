-- 04_organization_membership.sql
-- Purpose: Verify organization membership functions work correctly

BEGIN;

SELECT plan(11);

-- ========================================
-- TEST: list_organization_members returns correct data
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

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
   WHERE user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')),
  'Maria should show as super_admin in member list'
);

SELECT ok(
  NOT (SELECT is_super_admin FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
       WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')),
  'Carlos should NOT show as super_admin in member list'
);

-- ========================================
-- TEST: list_organization_members shows correct roles
-- ========================================
SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')),
  'super_admin',
  'Maria should have super_admin role'
);

SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')),
  'manager',
  'Carlos should have manager role'
);

-- ========================================
-- TEST: Organization isolation - Pizza Palace members
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM public.list_organization_members('cccccccc-cccc-cccc-cccc-cccccccccccc')),
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
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Soft-delete Taylor's membership
SELECT public.remove_member_from_organization(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
);

SELECT is(
  (SELECT COUNT(*)::int FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  6,
  'After soft-delete, Bella Italia should have 6 active members'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
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

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT ok(
  NOT core.is_org_member('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Luigi should NOT be detected as Bella Italia member'
);

SELECT * FROM finish();

ROLLBACK;
