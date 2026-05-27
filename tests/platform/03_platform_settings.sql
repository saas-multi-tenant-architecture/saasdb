-- 03_platform_settings.sql
-- Purpose: Test platform settings management functions

BEGIN;

SELECT plan(10);

-- Sarah's JWT identity drives SECURITY DEFINER functions
-- (get_setting/list_settings/set_setting/delete_setting), but direct SELECTs on
-- platform.platform_settings require service_role because authenticated has no
-- direct grants on platform tables.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sarah@pizzatech-saas.com'));
SELECT test_helpers.set_service_role();

-- ========================================
-- TEST: Settings exist
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.platform_settings),
  3,
  'Should have 3 platform settings'
);

-- ========================================
-- TEST: get_setting returns correct value
-- ========================================
SELECT is(
  platform.get_setting('maintenance_mode'),
  'false',
  'get_setting should return maintenance_mode value'
);

SELECT is(
  platform.get_setting('max_organizations'),
  '100',
  'get_setting should return max_organizations value'
);

-- ========================================
-- TEST: get_setting returns NULL for non-existent key
-- ========================================
SELECT ok(
  platform.get_setting('nonexistent_key') IS NULL,
  'get_setting should return NULL for non-existent key'
);

-- ========================================
-- TEST: list_settings returns all settings
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.list_settings()),
  3,
  'list_settings should return all settings'
);

-- ========================================
-- TEST: set_setting updates existing setting
-- ========================================
SELECT lives_ok(
  $$SELECT platform.set_setting('maintenance_mode', 'true')$$,
  'set_setting should succeed for existing key'
);

SELECT is(
  platform.get_setting('maintenance_mode'),
  'true',
  'Setting should be updated'
);

-- ========================================
-- TEST: set_setting creates new setting
-- ========================================
SELECT lives_ok(
  $$SELECT platform.set_setting('new_setting', '{"key": "value"}')$$,
  'set_setting should create new setting'
);

SELECT is(
  platform.get_setting('new_setting'),
  '{"key": "value"}',
  'New setting should be retrievable'
);

-- ========================================
-- TEST: delete_setting removes setting
-- ========================================
SELECT lives_ok(
  $$SELECT platform.delete_setting('new_setting')$$,
  'delete_setting should succeed'
);

SELECT * FROM finish();

ROLLBACK;
