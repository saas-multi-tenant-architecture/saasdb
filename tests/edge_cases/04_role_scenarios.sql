-- 04_role_scenarios.sql
-- Purpose: Test various role-based access scenarios

BEGIN;

SELECT plan(12);

-- ========================================
-- SETUP: Get user IDs
-- ========================================
DO $$
DECLARE
  v_maria_id UUID;
  v_carlos_id UUID;
  v_alex_id UUID;
  v_sam_id UUID;
  v_taylor_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');
  v_carlos_id := test_helpers.get_test_user_id('carlos@test.bellaitalia.com');
  v_alex_id := test_helpers.get_test_user_id('alex@test.bellaitalia.com');
  v_sam_id := test_helpers.get_test_user_id('sam@test.bellaitalia.com');
  v_taylor_id := test_helpers.get_test_user_id('taylor@test.bellaitalia.com');
  PERFORM set_config('test.maria_id', v_maria_id::text, true);
  PERFORM set_config('test.carlos_id', v_carlos_id::text, true);
  PERFORM set_config('test.alex_id', v_alex_id::text, true);
  PERFORM set_config('test.sam_id', v_sam_id::text, true);
  PERFORM set_config('test.taylor_id', v_taylor_id::text, true);
END $$;

-- ========================================
-- TEST: Super_admin can access all org data
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

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
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Manager can see all units (org member access)'
);

-- ========================================
-- TEST: Team member can access org data
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sam@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Team member can see all units (org member access)'
);

-- ========================================
-- TEST: Org-only member (no unit assignments) can access org data
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('taylor@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Org-only member can see all units'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   WHERE um.user_id = current_setting('test.taylor_id')::uuid),
  0,
  'Taylor has no unit memberships'
);

-- ========================================
-- TEST: User with multiple unit roles
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('alex@test.bellaitalia.com'));

-- Alex is team at Downtown, manager at Mall
SELECT is(
  (SELECT role FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
   WHERE user_id = current_setting('test.alex_id')::uuid),
  'team',
  'Alex is team at Downtown'
);

SELECT is(
  (SELECT role FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03')
   WHERE user_id = current_setting('test.alex_id')::uuid),
  'manager',
  'Alex is manager at Mall'
);

-- ========================================
-- TEST: User with same role at multiple units
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

-- Carlos is manager at both Downtown and Airport
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = current_setting('test.carlos_id')::uuid
      AND um.unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01' -- Downtown
      AND r.name = 'manager'
  ),
  'Carlos is manager at Downtown'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = current_setting('test.carlos_id')::uuid
      AND um.unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02' -- Airport
      AND r.name = 'manager'
  ),
  'Carlos is manager at Airport'
);

-- ========================================
-- TEST: Org role vs unit role independence
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('alex@test.bellaitalia.com'));

-- Alex is team at org level, but also manager at Mall unit (independent roles)
SELECT is(
  (SELECT r.name FROM core.memberships m
   JOIN core.roles r ON r.id = m.role_id
   WHERE m.user_id = current_setting('test.alex_id')::uuid
     AND m.organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'team',
  'Alex org role is team'
);

SELECT is(
  (SELECT r.name FROM core.unit_memberships um
   JOIN core.roles r ON r.id = um.role_id
   WHERE um.user_id = current_setting('test.alex_id')::uuid
     AND um.unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'),
  'team',
  'Alex unit role at Downtown is team (same as org role, different from Mall unit role)'
);

SELECT * FROM finish();

ROLLBACK;
