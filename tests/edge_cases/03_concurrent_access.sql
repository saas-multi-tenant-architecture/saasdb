-- 03_concurrent_access.sql
-- Purpose: Test concurrent access patterns and unique constraint enforcement

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql
\i tests/fixtures/04_pizza_palace.sql

SELECT plan(10);

-- ========================================
-- TEST: Unique constraint on role names
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.roles (name, description, created_by, updated_by)
    VALUES ('super_admin', 'Duplicate role',
            '11111111-1111-1111-1111-111111111101',
            '11111111-1111-1111-1111-111111111101')$$,
  '23505', -- unique_violation
  'Cannot create duplicate role name'
);

-- ========================================
-- TEST: Unique constraint on org name (if exists) or just test insert
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

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
  $$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111101',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '00000000-0000-0000-0000-000000000003',
      false,
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  '23505', -- unique_violation (if there's a unique constraint on user+org)
  'Cannot create duplicate membership'
);

-- ========================================
-- TEST: Only one super_admin per org (unique partial index)
-- ========================================
SELECT throws_ok(
  $$UPDATE core.memberships
    SET is_super_admin = true
    WHERE user_id = '11111111-1111-1111-1111-111111111102' -- Carlos
      AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  '23505', -- unique_violation
  'Cannot have two super_admins in same org'
);

-- ========================================
-- TEST: Unique unit_membership per user+unit (if constraint exists)
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
    VALUES (
      '11111111-1111-1111-1111-111111111102', -- Carlos
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', -- Downtown (already a member)
      '00000000-0000-0000-0000-000000000003',
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  '23505', -- unique_violation
  'Cannot create duplicate unit membership'
);

-- ========================================
-- TEST: User email uniqueness in users_meta
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
    VALUES (
      gen_random_uuid(),
      'maria@bellaitalia.com', -- Duplicate email
      'Fake',
      'Maria',
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  '23505', -- unique_violation
  'Cannot create duplicate user email'
);

-- ========================================
-- TEST: Platform settings key uniqueness
-- ========================================
SELECT throws_ok(
  $$INSERT INTO platform.platform_settings (key, value, created_by, updated_by)
    VALUES (
      'maintenance_mode', -- Duplicate key
      '"new_value"',
      '11111111-1111-1111-1111-111111111101',
      '11111111-1111-1111-1111-111111111101'
    )$$,
  '23505', -- unique_violation
  'Cannot create duplicate platform setting key'
);

-- ========================================
-- TEST: Platform role name uniqueness
-- ========================================
SELECT throws_ok(
  $$INSERT INTO platform.platform_roles (name, description)
    VALUES ('platform_super_admin', 'Duplicate role')$$,
  '23505', -- unique_violation
  'Cannot create duplicate platform role name'
);

-- ========================================
-- TEST: Super_admin can be set when previous is deleted
-- ========================================
-- First transfer to Carlos
SELECT public.transfer_super_admin(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111102'
);

-- Now Maria can be set as super_admin again via another transfer
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos is now super_admin

SELECT lives_ok(
  $$SELECT public.transfer_super_admin(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111101' -- Maria
  )$$,
  'Can transfer super_admin back to original user'
);

-- Verify Maria is super_admin again
SELECT ok(
  (SELECT is_super_admin FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111101'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Maria should be super_admin again after transfer'
);

SELECT * FROM finish();

ROLLBACK;
