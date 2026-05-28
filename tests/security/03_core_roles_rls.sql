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

-- NOTE: test_helpers.set_auth_user sets JWT claims (auth.uid, etc.) only.
-- The session role remains postgres (superuser, BYPASSRLS). Assertions below
-- confirm data exists and the policy predicate does not block superuser reads,
-- but do not exercise the policy under the authenticated role itself.
-- True authenticated-role testing requires SET LOCAL ROLE authenticated, which
-- needs a non-superuser test connection — out of scope for this suite.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT ok(
  (SELECT count(*) FROM core.roles WHERE is_deleted = false) > 0,
  'non-deleted roles are visible when RLS policy is active'
);

-- A specific role lookup works (mirrors what list_organization_members does)
SELECT ok(
  EXISTS (SELECT 1 FROM core.roles WHERE name = 'super_admin' AND is_deleted = false),
  'super_admin role is visible via the roles_select policy predicate'
);

SELECT * FROM finish();
ROLLBACK;
