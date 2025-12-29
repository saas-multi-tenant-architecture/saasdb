-- 04_role_scenarios.sql
-- Purpose: Test various role-based access scenarios

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: Super_admin can access all org data
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria (super_admin)

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Super_admin can see all units'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  7,
  'Super_admin can see all memberships'
);

-- ========================================
-- TEST: Manager can access org data
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos (manager)

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Manager can see all units (org member access)'
);

-- ========================================
-- TEST: Team member can access org data
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111106'); -- Sam (team)

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Team member can see all units (org member access)'
);

-- ========================================
-- TEST: Org-only member (no unit assignments) can access org data
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111107'); -- Taylor (org member only)

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Org-only member can see all units'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   WHERE um.user_id = '11111111-1111-1111-1111-111111111107'),
  0,
  'Taylor has no unit memberships'
);

-- ========================================
-- TEST: User with multiple unit roles
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111104'); -- Alex

-- Alex is team at Downtown, manager at Mall
SELECT is(
  (SELECT role FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
   WHERE user_id = '11111111-1111-1111-1111-111111111104'),
  'team',
  'Alex is team at Downtown'
);

SELECT is(
  (SELECT role FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000003')
   WHERE user_id = '11111111-1111-1111-1111-111111111104'),
  'manager',
  'Alex is manager at Mall'
);

-- ========================================
-- TEST: User with same role at multiple units
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

-- Carlos is manager at both Downtown and Airport
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = '11111111-1111-1111-1111-111111111102'
      AND um.unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001' -- Downtown
      AND r.name = 'manager'
  ),
  'Carlos is manager at Downtown'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = '11111111-1111-1111-1111-111111111102'
      AND um.unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000002' -- Airport
      AND r.name = 'manager'
  ),
  'Carlos is manager at Airport'
);

-- ========================================
-- TEST: Org role vs unit role independence
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111104'); -- Alex

-- Alex is manager at org level, but team at Downtown unit
SELECT is(
  (SELECT r.name FROM core.memberships m
   JOIN core.roles r ON r.id = m.role_id
   WHERE m.user_id = '11111111-1111-1111-1111-111111111104'
     AND m.organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'manager',
  'Alex org role is manager'
);

SELECT is(
  (SELECT r.name FROM core.unit_memberships um
   JOIN core.roles r ON r.id = um.role_id
   WHERE um.user_id = '11111111-1111-1111-1111-111111111104'
     AND um.unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001'),
  'team',
  'Alex unit role at Downtown is team (independent of org role)'
);

SELECT * FROM finish();

ROLLBACK;
