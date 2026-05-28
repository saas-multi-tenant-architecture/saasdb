-- 03_core_roles_rls.sql
-- Purpose: Verify RLS is enabled on core.roles AND a SELECT policy exists
-- so authenticated users can read role reference data.

BEGIN;

SELECT plan(4);

-- RLS is enabled
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'core.roles'::regclass),
  'core.roles must have RLS enabled'
);

-- A SELECT policy exists
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'core'
      AND tablename = 'roles'
      AND cmd = 'SELECT'
  ),
  'core.roles must have at least one SELECT policy'
);

-- authenticated can SELECT (the policy actually allows reads)
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT ok(
  (SELECT count(*) FROM core.roles WHERE is_deleted = false) > 0,
  'authenticated user can SELECT non-deleted rows from core.roles'
);

-- A specific role lookup works (mirrors what list_organization_members does)
SELECT ok(
  EXISTS (SELECT 1 FROM core.roles WHERE name = 'super_admin' AND is_deleted = false),
  'authenticated user can find super_admin role by name'
);

SELECT * FROM finish();
ROLLBACK;
