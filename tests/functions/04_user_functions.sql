-- 04_user_functions.sql
-- Purpose: Test public user management functions

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql

SELECT plan(10);

-- ========================================
-- TEST: get_user_profile returns current user data
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT ok(
  (SELECT first_name FROM public.get_user_profile()) = 'Maria',
  'get_user_profile should return Maria as first_name'
);

SELECT ok(
  (SELECT last_name FROM public.get_user_profile()) = 'Rossi',
  'get_user_profile should return Rossi as last_name'
);

SELECT ok(
  (SELECT email FROM public.get_user_profile()) = 'maria@bellaitalia.com',
  'get_user_profile should return correct email'
);

-- ========================================
-- TEST: update_user_profile works
-- ========================================
SELECT lives_ok(
  $$SELECT public.update_user_profile('Maria Updated', 'Rossi Updated')$$,
  'update_user_profile should succeed'
);

SELECT ok(
  (SELECT first_name FROM public.get_user_profile()) = 'Maria Updated',
  'First name should be updated'
);

SELECT ok(
  (SELECT last_name FROM public.get_user_profile()) = 'Rossi Updated',
  'Last name should be updated'
);

-- ========================================
-- TEST: get_user_organizations returns orgs for current user
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_organizations()),
  1,
  'Maria should belong to 1 organization'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.get_user_organizations()
    WHERE name = 'Bella Italia Restaurant Group'
  ),
  'Maria should belong to Bella Italia'
);

-- ========================================
-- TEST: get_user_units returns units for current user in org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

-- Carlos is in Downtown and Airport
SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_units('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  2,
  'Carlos should be in 2 units'
);

-- ========================================
-- TEST: User with no unit memberships
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111107'); -- Taylor

SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_units('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  0,
  'Taylor should be in 0 units (org member only)'
);

SELECT * FROM finish();

ROLLBACK;
