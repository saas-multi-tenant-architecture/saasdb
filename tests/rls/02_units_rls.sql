-- 02_units_rls.sql
-- Purpose: Verify RLS policies on core.units table

BEGIN;

SELECT plan(14);

-- ========================================
-- TEST: Org member can SELECT all units in their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria (Bella Italia)

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
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'Maria cannot see Pizza Palace units'
);

-- ========================================
-- TEST: Unit member can SELECT their unit
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos (Downtown + Airport)

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001' -- Downtown
  ),
  'Carlos can SELECT Downtown unit'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000002' -- Airport
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
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000003' -- Mall
  ),
  'Carlos can see Mall unit (org member access)'
);

-- ========================================
-- TEST: Super_admin can INSERT new unit
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT lives_ok(
  $$INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'New Location',
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  'Maria (super_admin) can INSERT new unit'
);

-- ========================================
-- TEST: Regular member can INSERT unit (permissive RLS)
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

SELECT lives_ok(
  $$INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000005',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'Carlos Location',
      '11111111-1111-1111-1111-111111111102',
      '11111111-1111-1111-1111-111111111102'
    )$$,
  'Carlos (manager) can INSERT new unit (permissive RLS)'
);

-- ========================================
-- TEST: Cannot INSERT unit into other organization
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-000000000099',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'Should Fail',
      '11111111-1111-1111-1111-111111111102',
      '11111111-1111-1111-1111-111111111102'
    )$$,
  '42501', -- insufficient_privilege
  'Carlos cannot INSERT unit into Pizza Palace'
);

-- ========================================
-- TEST: Member can UPDATE unit in their org
-- ========================================
SELECT lives_ok(
  $$UPDATE core.units
    SET description = 'Updated by Carlos'
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001'$$,
  'Carlos can UPDATE Downtown unit'
);

-- ========================================
-- TEST: Cannot UPDATE unit in other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.units
    SET description = 'Should not work'
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-000000000001'
    RETURNING id
  ) u),
  0,
  'Carlos cannot UPDATE Pizza Palace unit'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM core.units
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
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
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

UPDATE core.units
SET is_deleted = true, deleted_at = now()
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000004'; -- New Location we created

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.units
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000004'
  ),
  'Soft-deleted unit should not be visible'
);

SELECT * FROM finish();

ROLLBACK;
