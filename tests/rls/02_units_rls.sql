-- 02_units_rls.sql
-- Purpose: Verify RLS policies on core.units table

BEGIN;

SELECT plan(14);

-- ========================================
-- TEST: Org member can SELECT all units in their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  3,
  'Maria can see all 3 Bella Italia units'
);

-- ========================================
-- TEST: Org member cannot SELECT units from other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'Maria cannot see Pizza Palace units'
);

-- ========================================
-- TEST: Unit member can SELECT their unit
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01' -- Downtown
  ),
  'Carlos can SELECT Downtown unit'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02' -- Airport
  ),
  'Carlos can SELECT Airport unit'
);

-- ========================================
-- TEST: Org member can see all units (not just their assigned ones)
-- ========================================
-- Carlos is in Downtown and Airport, but can still see Mall (org member)
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03' -- Mall
  ),
  'Carlos can see Mall unit (org member access)'
);

-- ========================================
-- TEST: Super_admin can INSERT new unit
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
      VALUES (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb04',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'New Location',
        %L,
        %L
      )$$,
    test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
    test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Maria (super_admin) can INSERT new unit'
);

-- ========================================
-- TEST: Regular member can INSERT unit (permissive RLS)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
      VALUES (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb05',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'Carlos Location',
        %L,
        %L
      )$$,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Carlos (manager) can INSERT new unit (permissive RLS)'
);

-- ========================================
-- TEST: Cannot INSERT unit into other organization
-- ========================================
SELECT throws_ok(
  format(
    $$INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
      VALUES (
        'dddddddd-dddd-dddd-dddd-dddddddddd99',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'Should Fail',
        %L,
        %L
      )$$,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  '42501', -- insufficient_privilege
  NULL,
  'Carlos cannot INSERT unit into Pizza Palace'
);

-- ========================================
-- TEST: Member can UPDATE unit in their org
-- ========================================
SELECT lives_ok(
  $$UPDATE core.units
    SET description = 'Updated by Carlos'
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'$$,
  'Carlos can UPDATE Downtown unit'
);

-- ========================================
-- TEST: Cannot UPDATE unit in other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.units
    SET description = 'Should not work'
    WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddd01'
    RETURNING id
  ) u),
  0,
  'Carlos cannot UPDATE Pizza Palace unit'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  1,
  'Luigi can see 1 Pizza Palace unit'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'Luigi cannot see Bella Italia units'
);

-- ========================================
-- TEST: Soft-deleted units not visible
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

UPDATE core.units
SET is_deleted = true, deleted_at = now()
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb04'; -- New Location we created

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb04'
  ),
  'Soft-deleted unit should not be visible'
);

SELECT * FROM finish();

ROLLBACK;
