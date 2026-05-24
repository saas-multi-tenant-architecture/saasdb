-- 08_organizations_meta_rls.sql
-- Purpose: Verify RLS policies on core.organizations_meta table

BEGIN;

SELECT plan(8);

-- ========================================
-- TEST: Member can SELECT own organization meta
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Maria can SELECT Bella Italia organizations_meta'
);

-- ========================================
-- TEST: Member cannot SELECT other organization meta
-- ========================================
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'Maria cannot SELECT Pizza Palace organizations_meta'
);

-- ========================================
-- TEST: Super_admin can UPDATE own organization meta
-- ========================================
SELECT lives_ok(
  $$UPDATE core.organizations_meta
    SET timezone = 'America/New_York'
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Maria (super_admin) can UPDATE Bella Italia organizations_meta'
);

SELECT is(
  (SELECT timezone FROM core.organizations_meta WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'America/New_York',
  'Timezone should be updated'
);

-- ========================================
-- TEST: Regular member can SELECT but cannot UPDATE organization meta
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Carlos can SELECT Bella Italia organizations_meta'
);

DO $$
DECLARE v_count INT;
BEGIN
  UPDATE core.organizations_meta SET locale = 'es-ES'
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM set_config('test.carlos_meta_update_count', v_count::text, true);
END $$;

SELECT is(
  current_setting('test.carlos_meta_update_count')::int,
  0,
  'Carlos cannot UPDATE Bella Italia organizations_meta'
);

-- ========================================
-- TEST: Cross-org isolation with Luigi
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'Luigi can SELECT Pizza Palace organizations_meta'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Luigi cannot SELECT Bella Italia organizations_meta'
);

SELECT * FROM finish();

ROLLBACK;
