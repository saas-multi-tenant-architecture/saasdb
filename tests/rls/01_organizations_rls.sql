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
-- TEST: Regular member can UPDATE own organization (RLS is permissive)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT lives_ok(
  $$UPDATE core.organizations
    SET description = 'Carlos update'
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Carlos (manager) can UPDATE Bella Italia (RLS is permissive, CASL restricts)'
);

-- ========================================
-- TEST: Member cannot UPDATE other organization
-- ========================================
-- Carlos trying to update Pizza Palace (should affect 0 rows due to SELECT policy)
SELECT is(
  (SELECT COUNT(*)::int FROM (
    UPDATE core.organizations
    SET description = 'Should not work'
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    RETURNING id
  ) u),
  0,
  'Carlos cannot UPDATE Pizza Palace (not visible)'
);

-- ========================================
-- TEST: Super_admin can soft-delete own organization
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$UPDATE core.organizations
      SET is_deleted = true, deleted_at = now(), deleted_by = %L
      WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Maria (super_admin) can soft-delete Bella Italia'
);

-- Restore for further tests
UPDATE core.organizations
SET is_deleted = false, deleted_at = NULL, deleted_by = NULL
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ========================================
-- TEST: Soft-deleted organization is not visible
-- ========================================
UPDATE core.organizations
SET is_deleted = true, deleted_at = now()
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Soft-deleted organization is not visible'
);

-- Restore
UPDATE core.organizations
SET is_deleted = false, deleted_at = NULL
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

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

SELECT * FROM finish();

ROLLBACK;
