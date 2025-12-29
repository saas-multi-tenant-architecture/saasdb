-- 03_memberships_rls.sql
-- Purpose: Verify RLS policies on core.memberships table

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql
\i tests/fixtures/04_pizza_palace.sql

SELECT plan(14);

-- ========================================
-- TEST: Member can SELECT memberships in their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT is(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false),
  7,
  'Maria can see all 7 Bella Italia memberships'
);

-- ========================================
-- TEST: Cannot SELECT memberships from other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'Maria cannot see Pizza Palace memberships'
);

-- ========================================
-- TEST: Super_admin can INSERT new membership
-- ========================================
-- Create a new test user first
INSERT INTO auth.users (id, email) VALUES ('11111111-1111-1111-1111-111111111199', 'newuser@test.com');
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES ('11111111-1111-1111-1111-111111111199', 'newuser@test.com', 'New', 'User',
        '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101');

SELECT lives_ok(
  $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111199',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '00000000-0000-0000-0000-000000000003',
      false,
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  'Maria (super_admin) can INSERT new membership'
);

-- ========================================
-- TEST: Regular member can INSERT membership (permissive RLS)
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

INSERT INTO auth.users (id, email) VALUES ('11111111-1111-1111-1111-111111111198', 'anotheruser@test.com');
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES ('11111111-1111-1111-1111-111111111198', 'anotheruser@test.com', 'Another', 'User',
        '11111111-1111-1111-1111-111111111102', '11111111-1111-1111-1111-111111111102');

SELECT lives_ok(
  $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111198',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '00000000-0000-0000-0000-000000000003',
      false,
      '11111111-1111-1111-1111-111111111102',
      '11111111-1111-1111-1111-111111111102'
    )$$,
  'Carlos (manager) can INSERT membership (permissive RLS)'
);

-- ========================================
-- TEST: Cannot INSERT membership into other org
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111198',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      '00000000-0000-0000-0000-000000000003',
      false,
      '11111111-1111-1111-1111-111111111102',
      '11111111-1111-1111-1111-111111111102'
    )$$,
  '42501', -- insufficient_privilege
  'Carlos cannot INSERT membership into Pizza Palace'
);

-- ========================================
-- TEST: Member can UPDATE membership in their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT lives_ok(
  $$UPDATE core.memberships
    SET role_id = '00000000-0000-0000-0000-000000000002' -- change to manager
    WHERE user_id = '11111111-1111-1111-1111-111111111106' -- Sam
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Maria can UPDATE membership role'
);

-- ========================================
-- TEST: Cannot UPDATE membership in other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.memberships
    SET role_id = '00000000-0000-0000-0000-000000000002'
    WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    RETURNING id
  ) u),
  0,
  'Maria cannot UPDATE Pizza Palace memberships'
);

-- ========================================
-- TEST: Can soft-delete non-super_admin membership
-- ========================================
SELECT lives_ok(
  $$UPDATE core.memberships
    SET is_deleted = true, deleted_at = now(), deleted_by = '11111111-1111-1111-1111-111111111101'
    WHERE user_id = '11111111-1111-1111-1111-111111111199'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Maria can soft-delete non-super_admin membership'
);

-- ========================================
-- TEST: Soft-deleted memberships not visible
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = '11111111-1111-1111-1111-111111111199'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Soft-deleted membership not visible in SELECT'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
     AND is_deleted = false),
  2,
  'Luigi can see 2 Pizza Palace memberships'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'Luigi cannot see Bella Italia memberships'
);

-- ========================================
-- TEST: User can see their own membership info
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = '11111111-1111-1111-1111-111111111102'
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Carlos can see his own membership'
);

SELECT * FROM finish();

ROLLBACK;
