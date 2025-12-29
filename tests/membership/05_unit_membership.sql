-- 05_unit_membership.sql
-- Purpose: Verify unit membership functions work correctly

BEGIN;

SELECT plan(14);

-- ========================================
-- TEST: list_unit_members returns correct data for Downtown
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

-- Downtown should have: Carlos (manager), Sofia (manager), Alex (team), Sam (team)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')),
  4,
  'Downtown location should have 4 members'
);

-- ========================================
-- TEST: Airport unit members
-- ========================================
-- Airport should have: Carlos (manager), Jordan (team)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000002')),
  2,
  'Airport location should have 2 members'
);

-- ========================================
-- TEST: Mall unit members
-- ========================================
-- Mall should have: Alex (manager), Jordan (team)
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000003')),
  2,
  'Mall location should have 2 members'
);

-- ========================================
-- TEST: list_unit_members shows correct roles
-- ========================================
SELECT is(
  (SELECT role FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
   WHERE user_id = '11111111-1111-1111-1111-111111111102'),
  'manager',
  'Carlos should be manager at Downtown'
);

SELECT is(
  (SELECT role FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
   WHERE user_id = '11111111-1111-1111-1111-111111111104'),
  'team',
  'Alex should be team member at Downtown'
);

-- ========================================
-- TEST: User with different roles at different units
-- ========================================
-- Alex is team at Downtown but manager at Mall
SELECT is(
  (SELECT role FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000003')
   WHERE user_id = '11111111-1111-1111-1111-111111111104'),
  'manager',
  'Alex should be manager at Mall'
);

-- ========================================
-- TEST: User in multiple units
-- ========================================
-- Carlos is in Downtown and Airport
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
    WHERE user_id = '11111111-1111-1111-1111-111111111102'
  ),
  'Carlos should be in Downtown unit'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000002')
    WHERE user_id = '11111111-1111-1111-1111-111111111102'
  ),
  'Carlos should be in Airport unit'
);

-- ========================================
-- TEST: Unit isolation - Pizza Palace units
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-000000000001')),
  1,
  'Pizza Palace Main Street should have 1 member (Giuseppe)'
);

-- ========================================
-- TEST: Cannot see other organization unit members
-- ========================================
-- Luigi trying to list Bella Italia Downtown members
SELECT is(
  (SELECT COUNT(*)::int FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')),
  0,
  'Luigi should not see Bella Italia Downtown members (different org)'
);

-- ========================================
-- TEST: is_unit_member helper function
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

SELECT ok(
  core.is_unit_member('aaaaaaaa-aaaa-aaaa-aaaa-000000000001'),
  'Carlos should be detected as Downtown unit member'
);

SELECT ok(
  NOT core.is_unit_member('aaaaaaaa-aaaa-aaaa-aaaa-000000000003'),
  'Carlos should NOT be detected as Mall unit member'
);

-- ========================================
-- TEST: is_org_member_for_unit helper function
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111107'); -- Taylor (org member, no unit)

SELECT ok(
  core.is_org_member_for_unit('aaaaaaaa-aaaa-aaaa-aaaa-000000000001'),
  'Taylor (org member) should pass org check for Downtown unit'
);

SELECT ok(
  NOT core.is_unit_member('aaaaaaaa-aaaa-aaaa-aaaa-000000000001'),
  'Taylor should NOT be unit member of Downtown'
);

SELECT * FROM finish();

ROLLBACK;
