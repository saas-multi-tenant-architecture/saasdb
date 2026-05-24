-- 01_organizations_rls.sql
-- Purpose: Verify RLS policies on core.organizations table

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: Member can SELECT own organization
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Maria can SELECT Bella Italia'
);

-- ========================================
-- TEST: Member cannot SELECT other organization
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'Maria cannot SELECT Pizza Palace'
);

-- ========================================
-- TEST: Super_admin can UPDATE own organization
-- ========================================
SELECT lives_ok(
  $$UPDATE core.organizations
    SET description = 'Updated description'
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Maria (super_admin) can UPDATE Bella Italia'
);

-- ========================================
-- TEST: Regular member cannot UPDATE own organization
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

DO $$
DECLARE v_count INT;
BEGIN
  UPDATE core.organizations SET description = 'Carlos update' WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM set_config('test.carlos_update_count', v_count::text, true);
END $$;

SELECT is(
  current_setting('test.carlos_update_count')::int,
  0,
  'Carlos (manager) cannot UPDATE Bella Italia'
);

-- ========================================
-- TEST: Member cannot UPDATE other organization
-- ========================================
-- Carlos trying to update Pizza Palace (should affect 0 rows due to SELECT policy)
DO $$
DECLARE v_count INT;
BEGIN
  UPDATE core.organizations SET description = 'Should not work' WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM set_config('test.cross_org_update_count', v_count::text, true);
END $$;

SELECT is(
  current_setting('test.cross_org_update_count')::int,
  0,
  'Carlos cannot UPDATE Pizza Palace (not visible)'
);

-- ========================================
-- TEST: Cross-org isolation with Luigi
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'Luigi can SELECT Pizza Palace'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Luigi cannot SELECT Bella Italia'
);

-- ========================================
-- TEST: Count visible organizations per user
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.organizations),
  1,
  'Maria should see exactly 1 organization'
);

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.organizations),
  1,
  'Luigi should see exactly 1 organization'
);

-- ========================================
-- TEST: Super_admin can soft-delete own organization
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  $$SELECT public.delete_organization('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')$$,
  'Maria (super_admin) can soft-delete Bella Italia'
);

-- ========================================
-- TEST: Soft-deleted organization is not visible
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Soft-deleted organization is not visible'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.organizations),
  0,
  'Maria should see 0 organizations after soft-delete'
);

SELECT * FROM finish();

ROLLBACK;
