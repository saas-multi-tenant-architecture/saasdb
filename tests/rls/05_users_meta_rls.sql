-- 05_users_meta_rls.sql
-- Purpose: Verify RLS policies on core.users_meta table

BEGIN;

SELECT plan(10);

-- ========================================
-- TEST: User can SELECT their own profile
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Maria can SELECT her own profile'
);

-- ========================================
-- TEST: User can SELECT profiles of org members
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com') -- Carlos
  ),
  'Maria can SELECT Carlos profile (same org)'
);

-- ========================================
-- TEST: Cannot SELECT profiles from other org
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = test_helpers.get_test_user_id('luigi@test.pizzapalace.com') -- Luigi
  ),
  'Maria cannot SELECT Luigi profile (different org)'
);

-- ========================================
-- TEST: User can UPDATE their own profile
-- ========================================
SELECT lives_ok(
  $$UPDATE core.users_meta
    SET first_name = 'Maria Updated'
    WHERE id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')$$,
  'Maria can UPDATE her own profile'
);

-- ========================================
-- TEST: Super_admin can UPDATE other profiles in org
-- ========================================
SELECT lives_ok(
  $$UPDATE core.users_meta
    SET last_name = 'Hernandez Updated'
    WHERE id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')$$,
  'Maria (super_admin) can UPDATE Carlos profile'
);

-- ========================================
-- TEST: Cannot UPDATE profile from other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.users_meta
    SET first_name = 'Hacked'
    WHERE id = test_helpers.get_test_user_id('luigi@test.pizzapalace.com') -- Luigi
    RETURNING id
  ) u),
  0,
  'Maria cannot UPDATE Luigi profile (different org)'
);

-- ========================================
-- TEST: Regular member can see colleagues
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sam@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.users_meta um
   WHERE EXISTS (
     SELECT 1 FROM core.memberships m
     WHERE m.user_id = um.id
       AND m.organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       AND m.is_deleted = false
   )),
  7,
  'Sam can see all 7 Bella Italia team members'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT utils.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com')); -- Luigi

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
  ),
  'Luigi can SELECT his own profile'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = test_helpers.get_test_user_id('giuseppe@test.pizzapalace.com') -- Giuseppe
  ),
  'Luigi can SELECT Giuseppe profile (same org)'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = test_helpers.get_test_user_id('maria@test.bellaitalia.com') -- Maria
  ),
  'Luigi cannot SELECT Maria profile (different org)'
);

SELECT * FROM finish();

ROLLBACK;
