-- 01_roles_exist.sql
-- Purpose: Verify required roles are seeded and properly configured

BEGIN;

SELECT plan(9);

-- ========================================
-- TEST: super_admin role exists
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM core.roles WHERE name = 'super_admin'),
  'super_admin role should exist'
);

SELECT is(
  (SELECT id FROM core.roles WHERE name = 'super_admin')::text,
  '00000000-0000-0000-0000-000000000001',
  'super_admin role should have expected UUID'
);

SELECT ok(
  (SELECT casl_rules FROM core.roles WHERE name = 'super_admin') IS NOT NULL,
  'super_admin role should have casl_rules defined'
);

-- ========================================
-- TEST: manager role exists
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM core.roles WHERE name = 'manager'),
  'manager role should exist'
);

SELECT is(
  (SELECT id FROM core.roles WHERE name = 'manager')::text,
  '00000000-0000-0000-0000-000000000002',
  'manager role should have expected UUID'
);

SELECT ok(
  (SELECT casl_rules FROM core.roles WHERE name = 'manager') IS NOT NULL,
  'manager role should have casl_rules defined'
);

-- ========================================
-- TEST: team role exists
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM core.roles WHERE name = 'team'),
  'team role should exist'
);

SELECT is(
  (SELECT id FROM core.roles WHERE name = 'team')::text,
  '00000000-0000-0000-0000-000000000003',
  'team role should have expected UUID'
);

SELECT ok(
  (SELECT casl_rules FROM core.roles WHERE name = 'team') IS NOT NULL,
  'team role should have casl_rules defined'
);

SELECT * FROM finish();

ROLLBACK;
