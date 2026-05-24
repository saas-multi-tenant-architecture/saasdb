-- 03_concurrent_access.sql
-- Purpose: Test concurrent access patterns and unique constraint enforcement

BEGIN;

SELECT plan(10);

-- ========================================
-- SETUP: Get user IDs
-- ========================================
DO $$
DECLARE
  v_maria_id UUID;
  v_carlos_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');
  v_carlos_id := test_helpers.get_test_user_id('carlos@test.bellaitalia.com');
  PERFORM set_config('test.maria_id', v_maria_id::text, true);
  PERFORM set_config('test.carlos_id', v_carlos_id::text, true);
END $$;

-- ========================================
-- TEST: Unique constraint on role names
-- ========================================
SELECT throws_ok(
  format($$INSERT INTO core.roles (name, description, created_by, updated_by)
    VALUES ('super_admin', 'Duplicate role', %L, %L)$$,
    current_setting('test.maria_id')::uuid,
    current_setting('test.maria_id')::uuid),
  '23505', -- unique_violation
  NULL,
  'Cannot create duplicate role name'
);

-- ========================================
-- TEST: Unique constraint on org name (if exists) or just test insert
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Create org, should work
SELECT lives_ok(
  $$SELECT public.create_organization('Unique Org 1', 'Test')$$,
  'Can create organization with unique name'
);

-- ========================================
-- TEST: Duplicate membership user+org should fail (if unique constraint exists)
-- or succeed if allowing multiple (check actual behavior)
-- ========================================
-- Try to add Maria to Bella Italia again
SELECT throws_ok(
  format($$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
    VALUES (
      %L,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '00000000-0000-0000-0000-000000000003',
      false,
      %L,
      %L
    )$$,
    current_setting('test.maria_id')::uuid,
    current_setting('test.maria_id')::uuid,
    current_setting('test.maria_id')::uuid),
  '23505', -- unique_violation (if there's a unique constraint on user+org)
  NULL,
  'Cannot create duplicate membership'
);

-- ========================================
-- TEST: Only one super_admin per org (unique partial index)
-- ========================================
SELECT throws_ok(
  format($$UPDATE core.memberships
    SET is_super_admin = true
    WHERE user_id = %L
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    current_setting('test.carlos_id')::uuid),
  '23505', -- unique_violation
  NULL,
  'Cannot have two super_admins in same org'
);

-- ========================================
-- TEST: Unique unit_membership per user+unit (if constraint exists)
-- ========================================
SELECT throws_ok(
  format($$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
    VALUES (
      %L,
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', -- Downtown (already a member)
      '00000000-0000-0000-0000-000000000003',
      %L,
      %L
    )$$,
    current_setting('test.carlos_id')::uuid,
    current_setting('test.maria_id')::uuid,
    current_setting('test.maria_id')::uuid),
  '23505', -- unique_violation
  NULL,
  'Cannot create duplicate unit membership'
);

-- ========================================
-- TEST: Authenticated user cannot directly INSERT into users_meta (no INSERT RLS policy)
-- ========================================
SELECT throws_ok(
  format($$INSERT INTO core.users_meta (id, email, first_name, last_name)
    VALUES (gen_random_uuid(), 'newuser@example.com', 'New', 'User')$$),
  '42501', -- insufficient_privilege (no INSERT policy on users_meta)
  NULL,
  'Authenticated user cannot directly INSERT into users_meta'
);

-- ========================================
-- TEST: Platform settings key uniqueness
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sarah@pizzatech-saas.com'));

SELECT throws_ok(
  format($$INSERT INTO platform.platform_settings (key, value, created_by, updated_by)
    VALUES (
      'maintenance_mode', -- Duplicate key
      '"new_value"',
      %L,
      %L
    )$$,
    test_helpers.get_test_user_id('sarah@pizzatech-saas.com'),
    test_helpers.get_test_user_id('sarah@pizzatech-saas.com')),
  '23505', -- unique_violation
  NULL,
  'Cannot create duplicate platform setting key'
);

-- ========================================
-- TEST: Platform role name uniqueness
-- ========================================
SELECT throws_ok(
  $$INSERT INTO platform.platform_roles (name, description)
    VALUES ('super_admin', 'Duplicate role')$$,
  '23505', -- unique_violation
  NULL,
  'Cannot create duplicate platform role name'
);

-- ========================================
-- TEST: Super_admin can be set when previous is deleted
-- ========================================
-- First transfer to Carlos (must be called as Maria, who is super_admin)
SELECT test_helpers.set_auth_user(current_setting('test.maria_id')::uuid);

SELECT public.transfer_super_admin(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  current_setting('test.carlos_id')::uuid
);

-- Now Maria can be set as super_admin again via another transfer
SELECT test_helpers.set_auth_user(current_setting('test.carlos_id')::uuid); -- Carlos is now super_admin

SELECT lives_ok(
  format($$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    %L
  )$$, current_setting('test.maria_id')::uuid),
  'Can transfer super_admin back to original user'
);

-- Verify Maria is super_admin again
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = current_setting('test.maria_id')::uuid
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Maria should be super_admin again after transfer'
);

SELECT * FROM finish();

ROLLBACK;
