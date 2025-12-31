-- 04_unit_memberships_rls.sql
-- Purpose: Verify RLS policies on core.unit_memberships table

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: Org member can SELECT all unit_memberships in their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Count total unit memberships for Bella Italia (across all units)
SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   JOIN core.units u ON u.id = um.unit_id
   WHERE u.organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND um.is_deleted = false),
  8,
  'Maria can see all 8 Bella Italia unit_memberships'
);

-- ========================================
-- TEST: Cannot SELECT unit_memberships from other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   JOIN core.units u ON u.id = um.unit_id
   WHERE u.organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'Maria cannot see Pizza Palace unit_memberships'
);

-- ========================================
-- TEST: Unit member can see memberships for their unit
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships
   WHERE unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01' -- Downtown
     AND is_deleted = false),
  4,
  'Carlos can see 4 Downtown unit_memberships'
);

-- ========================================
-- TEST: Super_admin can INSERT unit_membership
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
      VALUES (
        %L,
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
        '00000000-0000-0000-0000-000000000003',
        %L,
        %L
      )$$,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
    test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
    test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Maria can INSERT unit_membership for Taylor'
);

-- ========================================
-- TEST: Regular member can INSERT unit_membership (permissive RLS)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

-- First remove the one we just added
DELETE FROM core.unit_memberships
WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

SELECT lives_ok(
  format(
    $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
      VALUES (
        %L,
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
        '00000000-0000-0000-0000-000000000003',
        %L,
        %L
      )$$,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Carlos can INSERT unit_membership (permissive RLS)'
);

-- ========================================
-- TEST: Cannot INSERT unit_membership for unit in other org
-- ========================================
SELECT throws_ok(
  format(
    $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
      VALUES (
        %L,
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        '00000000-0000-0000-0000-000000000003',
        %L,
        %L
      )$$,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  '42501', -- insufficient_privilege
  NULL,
  'Carlos cannot INSERT unit_membership into Pizza Palace unit'
);

-- ========================================
-- TEST: Member can UPDATE unit_membership in their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$UPDATE core.unit_memberships
      SET role_id = '00000000-0000-0000-0000-000000000002'
      WHERE user_id = %L
        AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'$$,
    test_helpers.get_test_user_id('sam@test.bellaitalia.com')
  ),
  'Maria can UPDATE Sam role in Downtown'
);

-- ========================================
-- TEST: Cannot UPDATE unit_membership in other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.unit_memberships
    SET role_id = '00000000-0000-0000-0000-000000000002'
    WHERE unit_id = 'dddddddd-dddd-dddd-dddd-dddddddddd01' -- Pizza Palace
    RETURNING id
  ) u),
  0,
  'Maria cannot UPDATE Pizza Palace unit_memberships'
);

-- ========================================
-- TEST: Soft-deleted unit_memberships not visible
-- ========================================
UPDATE core.unit_memberships
SET is_deleted = true, deleted_at = now()
WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
      AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
  ),
  'Soft-deleted unit_membership not visible'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   JOIN core.units u ON u.id = um.unit_id
   WHERE u.organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
     AND um.is_deleted = false),
  1,
  'Luigi can see 1 Pizza Palace unit_membership'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   JOIN core.units u ON u.id = um.unit_id
   WHERE u.organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'Luigi cannot see Bella Italia unit_memberships'
);

SELECT * FROM finish();

ROLLBACK;
