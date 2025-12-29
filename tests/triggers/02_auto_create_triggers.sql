-- 02_auto_create_triggers.sql
-- Purpose: Test that auto-creation triggers work correctly

BEGIN;

SELECT plan(8);

-- ========================================
-- TEST: Creating organization auto-creates organizations_meta
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

-- Create org directly (not via function, to test trigger)
INSERT INTO core.organizations (id, name, description, created_by, updated_by)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'Trigger Test Org',
  'Testing auto-create trigger',
  '11111111-1111-1111-1111-111111111101',
  '11111111-1111-1111-1111-111111111101'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'organizations_meta should be auto-created'
);

SELECT is(
  (SELECT created_by FROM core.organizations_meta WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  '11111111-1111-1111-1111-111111111101'::uuid,
  'organizations_meta.created_by should match organization creator'
);

-- ========================================
-- TEST: Creating unit auto-creates unit_meta
-- ========================================
INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
VALUES (
  'cccccccc-cccc-cccc-cccc-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'Trigger Test Unit',
  'Testing auto-create trigger',
  '11111111-1111-1111-1111-111111111101',
  '11111111-1111-1111-1111-111111111101'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.unit_meta
    WHERE id = 'cccccccc-cccc-cccc-cccc-000000000001'
  ),
  'unit_meta should be auto-created'
);

SELECT is(
  (SELECT created_by FROM core.unit_meta WHERE id = 'cccccccc-cccc-cccc-cccc-000000000001'),
  '11111111-1111-1111-1111-111111111101'::uuid,
  'unit_meta.created_by should match unit creator'
);

-- ========================================
-- TEST: Meta records have correct timestamps
-- ========================================
SELECT ok(
  (SELECT created_at FROM core.organizations_meta WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') IS NOT NULL,
  'organizations_meta.created_at should be set'
);

SELECT ok(
  (SELECT created_at FROM core.unit_meta WHERE id = 'cccccccc-cccc-cccc-cccc-000000000001') IS NOT NULL,
  'unit_meta.created_at should be set'
);

-- ========================================
-- TEST: Multiple units create separate meta records
-- ========================================
INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
VALUES (
  'cccccccc-cccc-cccc-cccc-000000000002',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'Second Trigger Test Unit',
  'Testing second unit',
  '11111111-1111-1111-1111-111111111101',
  '11111111-1111-1111-1111-111111111101'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.unit_meta
   WHERE id IN ('cccccccc-cccc-cccc-cccc-000000000001', 'cccccccc-cccc-cccc-cccc-000000000002')),
  2,
  'Each unit should have its own unit_meta record'
);

-- ========================================
-- TEST: Organization created via function also creates meta
-- ========================================
SELECT public.create_organization('Function Test Org', 'Created via function');

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
