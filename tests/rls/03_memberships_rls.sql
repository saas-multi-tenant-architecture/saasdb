-- 03_memberships_rls.sql
-- Purpose: Verify RLS policies on core.memberships table

BEGIN;

SELECT plan(14);

-- ========================================
-- TEST: Member can SELECT memberships in their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

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
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'Maria cannot see Pizza Palace memberships'
);

-- ========================================
-- TEST: Super_admin can INSERT new membership
-- ========================================
-- Store IDs for use in SQL
DO $$
DECLARE
  v_maria_id UUID;
  v_new_user_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');
  v_new_user_id := extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'newuser@rls.test.com');
  PERFORM set_config('test.maria_id', v_maria_id::text, true);
  PERFORM set_config('test.new_user_id', v_new_user_id::text, true);
END $$;

-- Create a new test user first
INSERT INTO auth.users (id, email) VALUES (current_setting('test.new_user_id')::uuid, 'newuser@rls.test.com');
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES (current_setting('test.new_user_id')::uuid, 'newuser@rls.test.com', 'New', 'User',
        current_setting('test.maria_id')::uuid, current_setting('test.maria_id')::uuid);

SELECT lives_ok(
  format(
    $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
      VALUES (
        %L,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '00000000-0000-0000-0000-000000000003',
        false,
        %L,
        %L
      )$$,
    current_setting('test.new_user_id')::uuid,
    current_setting('test.maria_id')::uuid,
    current_setting('test.maria_id')::uuid
  ),
  'Maria (super_admin) can INSERT new membership'
);

-- ========================================
-- TEST: Regular member can INSERT membership (permissive RLS)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

DO $$
DECLARE
  v_carlos_id UUID;
  v_another_user_id UUID;
BEGIN
  v_carlos_id := test_helpers.get_test_user_id('carlos@test.bellaitalia.com');
  v_another_user_id := extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'anotheruser@rls.test.com');
  PERFORM set_config('test.carlos_id', v_carlos_id::text, true);
  PERFORM set_config('test.another_user_id', v_another_user_id::text, true);
END $$;

INSERT INTO auth.users (id, email) VALUES (current_setting('test.another_user_id')::uuid, 'anotheruser@rls.test.com');
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES (current_setting('test.another_user_id')::uuid, 'anotheruser@rls.test.com', 'Another', 'User',
        current_setting('test.carlos_id')::uuid, current_setting('test.carlos_id')::uuid);

SELECT lives_ok(
  format(
    $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
      VALUES (
        %L,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '00000000-0000-0000-0000-000000000003',
        false,
        %L,
        %L
      )$$,
    current_setting('test.another_user_id')::uuid,
    current_setting('test.carlos_id')::uuid,
    current_setting('test.carlos_id')::uuid
  ),
  'Carlos (manager) can INSERT membership (permissive RLS)'
);

-- ========================================
-- TEST: Cannot INSERT membership into other org
-- ========================================
SELECT throws_ok(
  format(
    $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
      VALUES (
        %L,
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '00000000-0000-0000-0000-000000000003',
        false,
        %L,
        %L
      )$$,
    current_setting('test.another_user_id')::uuid,
    current_setting('test.carlos_id')::uuid,
    current_setting('test.carlos_id')::uuid
  ),
  '42501', -- insufficient_privilege
  NULL,
  'Carlos cannot INSERT membership into Pizza Palace'
);

-- ========================================
-- TEST: Member can UPDATE membership in their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$UPDATE core.memberships
      SET role_id = '00000000-0000-0000-0000-000000000002'
      WHERE user_id = %L
        AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    test_helpers.get_test_user_id('sam@test.bellaitalia.com')
  ),
  'Maria can UPDATE membership role'
);

-- ========================================
-- TEST: Cannot UPDATE membership in other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.memberships
    SET role_id = '00000000-0000-0000-0000-000000000002'
    WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    RETURNING id
  ) u),
  0,
  'Maria cannot UPDATE Pizza Palace memberships'
);

-- ========================================
-- TEST: Can soft-delete non-super_admin membership
-- ========================================
SELECT lives_ok(
  format(
    $$UPDATE core.memberships
      SET is_deleted = true, deleted_at = now(), deleted_by = %L
      WHERE user_id = %L
        AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    current_setting('test.maria_id')::uuid,
    current_setting('test.new_user_id')::uuid
  ),
  'Maria can soft-delete non-super_admin membership'
);

-- ========================================
-- TEST: Soft-deleted memberships not visible
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = current_setting('test.new_user_id')::uuid
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Soft-deleted membership not visible in SELECT'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.memberships
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
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
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Carlos can see his own membership'
);

SELECT * FROM finish();

ROLLBACK;
