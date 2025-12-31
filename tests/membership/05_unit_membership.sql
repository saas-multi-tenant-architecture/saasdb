-- 05_unit_membership.sql
-- Purpose: Verify unit membership functions work correctly
--
-- Unit IDs from fixtures:
--   Downtown: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01
--   Airport:  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02
--   Mall:     bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03
--   Pizza Palace Main Street: dddddddd-dddd-dddd-dddd-dddddddddd01

BEGIN;

SELECT plan(14);

-- ========================================
-- TEST: list_unit_members returns correct data for Downtown
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Downtown should have: Carlos (manager), Sofia (manager), Alex (team), Sam (team)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')),
  4,
  'Downtown location should have 4 members'
);

-- ========================================
-- TEST: Airport unit members
-- ========================================
-- Airport should have: Carlos (manager), Jordan (team)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02')),
  2,
  'Airport location should have 2 members'
);

-- ========================================
-- TEST: Mall unit members
-- ========================================
-- Mall should have: Alex (manager), Jordan (team)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03')),
  2,
  'Mall location should have 2 members'
);

-- ========================================
-- TEST: list_unit_members shows correct roles
-- ========================================
SELECT is(
  (SELECT role FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
   WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')),
  'manager',
  'Carlos should be manager at Downtown'
);

SELECT is(
  (SELECT role FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
   WHERE user_id = test_helpers.get_test_user_id('alex@test.bellaitalia.com')),
  'team',
  'Alex should be team member at Downtown'
);

-- ========================================
-- TEST: User with different roles at different units
-- ========================================
-- Alex is team at Downtown but manager at Mall
SELECT is(
  (SELECT role FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03')
   WHERE user_id = test_helpers.get_test_user_id('alex@test.bellaitalia.com')),
  'manager',
  'Alex should be manager at Mall'
);

-- ========================================
-- TEST: User in multiple units
-- ========================================
-- Carlos is in Downtown and Airport
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
    WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Carlos should be in Downtown unit'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02')
    WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Carlos should be in Airport unit'
);

-- ========================================
-- TEST: Unit isolation - Pizza Palace units
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('dddddddd-dddd-dddd-dddd-dddddddddd01')),
  1,
  'Pizza Palace Main Street should have 1 member (Giuseppe)'
);

-- ========================================
-- TEST: Cannot see other organization unit members
-- ========================================
-- Luigi trying to list Bella Italia Downtown members
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')),
  0,
  'Luigi should not see Bella Italia Downtown members (different org)'
);

-- ========================================
-- TEST: is_unit_member helper function
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT ok(
  core.is_unit_member('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'),
  'Carlos should be detected as Downtown unit member'
);

SELECT ok(
  NOT core.is_unit_member('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'),
  'Carlos should NOT be detected as Mall unit member'
);

-- ========================================
-- TEST: is_org_member_for_unit helper function
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('taylor@test.bellaitalia.com')); -- Taylor (org member, no unit)

SELECT ok(
  core.is_org_member_for_unit('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'),
  'Taylor (org member) should pass org check for Downtown unit'
);

SELECT ok(
  NOT core.is_unit_member('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'),
  'Taylor should NOT be unit member of Downtown'
);

SELECT * FROM finish();

ROLLBACK;
