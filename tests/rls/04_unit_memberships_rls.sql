-- 04_unit_memberships_rls.sql
-- Purpose: Verify RLS policies on core.unit_memberships table

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: Org member can SELECT all unit_memberships in their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

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
   WHERE u.organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'Maria cannot see Pizza Palace unit_memberships'
);

-- ========================================
-- TEST: Unit member can see memberships for their unit
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships
   WHERE unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001' -- Downtown
     AND is_deleted = false),
  4,
  'Carlos can see 4 Downtown unit_memberships'
);

-- ========================================
-- TEST: Super_admin can INSERT unit_membership
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT lives_ok(
  $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111107', -- Taylor (org member, no units)
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', -- Downtown
      '00000000-0000-0000-0000-000000000003', -- team
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  'Maria can INSERT unit_membership for Taylor'
);

-- ========================================
-- TEST: Regular member can INSERT unit_membership (permissive RLS)
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

-- First remove the one we just added
DELETE FROM core.unit_memberships
WHERE user_id = '11111111-1111-1111-1111-111111111107'
  AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

SELECT lives_ok(
  $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111107', -- Taylor
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', -- Downtown
      '00000000-0000-0000-0000-000000000003', -- team
      '11111111-1111-1111-1111-111111111102',
      '11111111-1111-1111-1111-111111111102'
    )$$,
  'Carlos can INSERT unit_membership (permissive RLS)'
);

-- ========================================
-- TEST: Cannot INSERT unit_membership for unit in other org
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111102', -- Carlos
      'bbbbbbbb-bbbb-bbbb-bbbb-000000000001', -- Pizza Palace Main Street
      '00000000-0000-0000-0000-000000000003',
      '11111111-1111-1111-1111-111111111102',
      '11111111-1111-1111-1111-111111111102'
    )$$,
  '42501', -- insufficient_privilege
  'Carlos cannot INSERT unit_membership into Pizza Palace unit'
);

-- ========================================
-- TEST: Member can UPDATE unit_membership in their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT lives_ok(
  $$UPDATE core.unit_memberships
    SET role_id = '00000000-0000-0000-0000-000000000002' -- promote to manager
    WHERE user_id = '11111111-1111-1111-1111-111111111106' -- Sam
      AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001' -- Downtown$$,
  'Maria can UPDATE Sam role in Downtown'
);

-- ========================================
-- TEST: Cannot UPDATE unit_membership in other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.unit_memberships
    SET role_id = '00000000-0000-0000-0000-000000000002'
    WHERE unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-000000000001' -- Pizza Palace
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
WHERE user_id = '11111111-1111-1111-1111-111111111107'
  AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
      AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001'
  ),
  'Soft-deleted unit_membership not visible'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_memberships um
   JOIN core.units u ON u.id = um.unit_id
   WHERE u.organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
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
