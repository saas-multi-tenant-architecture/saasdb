-- 04_feature_flags.sql
-- Purpose: Test platform feature flags management functions

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: Feature flags exist
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.platform_feature_flags),
  3,
  'Should have 3 feature flags'
);

-- ========================================
-- TEST: get_feature_flag returns correct value for global flag
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

SELECT is(
  (platform.get_feature_flag('dark_mode'))::text,
  '{"enabled": true}',
  'get_feature_flag should return dark_mode value'
);

-- ========================================
-- TEST: get_feature_flag returns org-specific flag
-- ========================================
SELECT is(
  (platform.get_feature_flag('beta_features', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'))::text,
  '{"dashboard_v2": true}',
  'get_feature_flag should return org-specific flag'
);

-- ========================================
-- TEST: get_feature_flag returns NULL for non-existent flag
-- ========================================
SELECT ok(
  platform.get_feature_flag('nonexistent_flag') IS NULL,
  'get_feature_flag should return NULL for non-existent flag'
);

-- ========================================
-- TEST: list_feature_flags returns active flags
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.list_feature_flags() WHERE is_active = true),
  2,
  'list_feature_flags should return 2 active flags'
);

-- ========================================
-- TEST: list_feature_flags can filter by org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.list_feature_flags('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  1,
  'list_feature_flags should return 1 flag for Bella Italia'
);

-- ========================================
-- TEST: update_feature_flag works
-- ========================================
SELECT lives_ok(
  $$SELECT platform.update_feature_flag(
    '30000000-0000-0000-0000-000000000001',
    '{"enabled": false}'::jsonb,
    true
  )$$,
  'update_feature_flag should succeed'
);

SELECT is(
  (platform.get_feature_flag('dark_mode'))::text,
  '{"enabled": false}',
  'Feature flag value should be updated'
);

-- ========================================
-- TEST: update_feature_flag can deactivate flag
-- ========================================
SELECT lives_ok(
  $$SELECT platform.update_feature_flag(
    '30000000-0000-0000-0000-000000000001',
    '{"enabled": false}'::jsonb,
    false
  )$$,
  'Can deactivate feature flag'
);

SELECT ok(
  NOT (SELECT is_active FROM platform.platform_feature_flags WHERE id = '30000000-0000-0000-0000-000000000001'),
  'Feature flag should be inactive'
);

-- ========================================
-- TEST: delete_feature_flag soft-deletes
-- ========================================
SELECT lives_ok(
  $$SELECT platform.delete_feature_flag('30000000-0000-0000-0000-000000000003')$$,
  'delete_feature_flag should succeed'
);

SELECT ok(
  (SELECT is_deleted FROM platform.platform_feature_flags WHERE id = '30000000-0000-0000-0000-000000000003'),
  'Feature flag should be soft-deleted'
);

SELECT * FROM finish();

ROLLBACK;
