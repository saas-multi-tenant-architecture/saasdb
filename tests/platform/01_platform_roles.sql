-- 01_platform_roles.sql
-- Purpose: Test platform roles exist and are configured correctly

BEGIN;

SELECT plan(9);

-- ========================================
-- TEST: platform_super_admin role exists
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM platform.platform_roles WHERE name = 'platform_super_admin'),
  'platform_super_admin role should exist'
);

SELECT is(
  (SELECT id FROM platform.platform_roles WHERE name = 'platform_super_admin')::text,
  '10000000-0000-0000-0000-000000000001',
  'platform_super_admin should have expected UUID'
);

SELECT ok(
  (SELECT casl_rules FROM platform.platform_roles WHERE name = 'platform_super_admin') IS NOT NULL,
  'platform_super_admin should have casl_rules defined'
);

-- ========================================
-- TEST: platform_admin role exists
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM platform.platform_roles WHERE name = 'platform_admin'),
  'platform_admin role should exist'
);

SELECT is(
  (SELECT id FROM platform.platform_roles WHERE name = 'platform_admin')::text,
  '10000000-0000-0000-0000-000000000002',
  'platform_admin should have expected UUID'
);

SELECT ok(
  (SELECT casl_rules FROM platform.platform_roles WHERE name = 'platform_admin') IS NOT NULL,
  'platform_admin should have casl_rules defined'
);

-- ========================================
-- TEST: platform_viewer role exists
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM platform.platform_roles WHERE name = 'platform_viewer'),
  'platform_viewer role should exist'
);

SELECT is(
  (SELECT id FROM platform.platform_roles WHERE name = 'platform_viewer')::text,
  '10000000-0000-0000-0000-000000000003',
  'platform_viewer should have expected UUID'
);

SELECT ok(
  (SELECT casl_rules FROM platform.platform_roles WHERE name = 'platform_viewer') IS NOT NULL,
  'platform_viewer should have casl_rules defined'
);

SELECT * FROM finish();

ROLLBACK;
