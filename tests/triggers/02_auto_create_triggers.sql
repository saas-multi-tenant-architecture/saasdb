-- 02_auto_create_triggers.sql
-- Purpose: Test that auto-creation triggers work correctly
--
-- Note: Uses eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee for test org to avoid
-- conflicts with Pizza Palace (cccccccc-cccc-cccc-cccc-cccccccccccc)

BEGIN;

SELECT plan(8);

-- ========================================
-- TEST: Creating organization auto-creates organizations_meta
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Store Maria's ID for later use
DO $$
BEGIN
  PERFORM set_config('test.maria_id', test_helpers.get_test_user_id('maria@test.bellaitalia.com')::text, true);
END $$;

-- Create org directly (not via function, to test trigger)
INSERT INTO core.organizations (id, name, description, created_by, updated_by)
VALUES (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'Trigger Test Org',
  'Testing auto-create trigger',
  current_setting('test.maria_id')::uuid,
  current_setting('test.maria_id')::uuid
);

-- Create membership for Maria so she can insert units
  SELECT test_helpers.seed_membership(
    current_setting('test.maria_id')::uuid,
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '00000000-0000-0000-0000-000000000001'::uuid,  -- super_admin role
    true  -- is_super_admin
  );

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
  ),
  'organizations_meta should be auto-created'
);

SELECT is(
  (SELECT created_by FROM core.organizations_meta WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  current_setting('test.maria_id')::uuid,
  'organizations_meta.created_by should match organization creator'
);

-- ========================================
-- TEST: Creating unit auto-creates unit_meta
-- ========================================
INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
VALUES (
  'eeeeeeee-eeee-eeee-eeee-000000000001',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'Trigger Test Unit',
  'Testing auto-create trigger',
  current_setting('test.maria_id')::uuid,
  current_setting('test.maria_id')::uuid
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_meta
    WHERE id = 'eeeeeeee-eeee-eeee-eeee-000000000001'
  ),
  'unit_meta should be auto-created'
);

SELECT is(
  (SELECT created_by FROM core.unit_meta WHERE id = 'eeeeeeee-eeee-eeee-eeee-000000000001'),
  current_setting('test.maria_id')::uuid,
  'unit_meta.created_by should match unit creator'
);

-- ========================================
-- TEST: Meta records have correct timestamps
-- ========================================
SELECT ok(
  (SELECT created_at FROM core.organizations_meta WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') IS NOT NULL,
  'organizations_meta.created_at should be set'
);

SELECT ok(
  (SELECT created_at FROM core.unit_meta WHERE id = 'eeeeeeee-eeee-eeee-eeee-000000000001') IS NOT NULL,
  'unit_meta.created_at should be set'
);

-- ========================================
-- TEST: Multiple units create separate meta records
-- ========================================
INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
VALUES (
  'eeeeeeee-eeee-eeee-eeee-000000000002',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'Second Trigger Test Unit',
  'Testing second unit',
  current_setting('test.maria_id')::uuid,
  current_setting('test.maria_id')::uuid
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_meta
   WHERE id IN ('eeeeeeee-eeee-eeee-eeee-000000000001', 'eeeeeeee-eeee-eeee-eeee-000000000002')),
  2,
  'Each unit should have its own unit_meta record'
);


-- ========================================
-- TEST: Organization created via function also creates meta
-- ========================================

-- Set user as Maria for this test
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT diag('auth.uid() returns: ' || COALESCE(auth.uid()::text, 'NULL'));

SELECT public.create_organization('Function Test Org');

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta om
    JOIN core.organizations o ON o.id = om.id
    WHERE o.name = 'Function Test Org'
  ),
  'organizations_meta should be created for function-created org'
);

SELECT * FROM finish();

ROLLBACK;
