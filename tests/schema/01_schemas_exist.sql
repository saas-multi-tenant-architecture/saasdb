-- 01_schemas_exist.sql
-- Purpose: Verify all required schemas exist

BEGIN;

SELECT plan(4);

-- ========================================
-- TEST: utils schema exists
-- ========================================
SELECT has_schema('utils', 'Schema "utils" should exist');

-- ========================================
-- TEST: core schema exists
-- ========================================
SELECT has_schema('core', 'Schema "core" should exist');

-- ========================================
-- TEST: app schema exists
-- ========================================
SELECT has_schema('app', 'Schema "app" should exist');

-- ========================================
-- TEST: platform schema exists
-- ========================================
SELECT has_schema('platform', 'Schema "platform" should exist');

SELECT * FROM finish();

ROLLBACK;
