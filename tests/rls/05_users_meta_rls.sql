-- 05_users_meta_rls.sql
-- Purpose: Verify RLS policies on core.users_meta table

BEGIN;

SELECT plan(10);

-- ========================================
-- TEST: User can SELECT their own profile
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = '11111111-1111-1111-1111-111111111101'
  ),
  'Maria can SELECT her own profile'
);

-- ========================================
-- TEST: User can SELECT profiles of org members
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = '11111111-1111-1111-1111-111111111102' -- Carlos
  ),
  'Maria can SELECT Carlos profile (same org)'
);

-- ========================================
-- TEST: Cannot SELECT profiles from other org
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = '11111111-1111-1111-1111-111111111201' -- Luigi
  ),
  'Maria cannot SELECT Luigi profile (different org)'
);

-- ========================================
-- TEST: User can UPDATE their own profile
-- ========================================
SELECT lives_ok(
  $$UPDATE core.users_meta
    SET first_name = 'Maria Updated'
    WHERE id = '11111111-1111-1111-1111-111111111101'$$,
  'Maria can UPDATE her own profile'
);

-- ========================================
-- TEST: Super_admin can UPDATE other profiles in org
-- ========================================
SELECT lives_ok(
  $$UPDATE core.users_meta
    SET last_name = 'Hernandez Updated'
    WHERE id = '11111111-1111-1111-1111-111111111102'$$,
  'Maria (super_admin) can UPDATE Carlos profile'
);

-- ========================================
-- TEST: Cannot UPDATE profile from other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.users_meta
    SET first_name = 'Hacked'
    WHERE id = '11111111-1111-1111-1111-111111111201' -- Luigi
    RETURNING id
  ) u),
  0,
  'Maria cannot UPDATE Luigi profile (different org)'
);

-- ========================================
-- TEST: Regular member can see colleagues
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111106'); -- Sam (team member)

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
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = '11111111-1111-1111-1111-111111111201'
  ),
  'Luigi can SELECT his own profile'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = '11111111-1111-1111-1111-111111111202' -- Giuseppe
  ),
  'Luigi can SELECT Giuseppe profile (same org)'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = '11111111-1111-1111-1111-111111111101' -- Maria
  ),
  'Luigi cannot SELECT Maria profile (different org)'
);

SELECT * FROM finish();

ROLLBACK;
