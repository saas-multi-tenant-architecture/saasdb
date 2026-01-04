-- 01_updated_at_triggers.sql
-- Purpose: Test that updated_at triggers work correctly
--
-- Unit IDs from fixtures:
--   Downtown: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01

BEGIN;

SELECT plan(8);

-- ========================================
-- TEST: organizations updated_at trigger
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Get initial updated_at
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM core.organizations
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1); -- Small delay to ensure timestamp changes
END $$;

UPDATE core.organizations
SET description = 'Updated to test trigger'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  (SELECT updated_at FROM core.organizations WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
  > current_setting('test.initial_ts')::timestamptz,
  'organizations.updated_at should be updated on change'
);

-- ========================================
-- TEST: units updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM core.units
  WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.units
SET description = 'Updated to test trigger'
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

SELECT ok(
  (SELECT updated_at FROM core.units WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
  > current_setting('test.initial_ts')::timestamptz,
  'units.updated_at should be updated on change'
);

-- ========================================
-- TEST: memberships updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
  v_carlos_id UUID;
BEGIN
  v_carlos_id := test_helpers.get_test_user_id('carlos@test.bellaitalia.com');

  SELECT updated_at INTO v_initial_updated_at
  FROM core.memberships
  WHERE user_id = v_carlos_id
    AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM set_config('test.carlos_id', v_carlos_id::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.memberships
SET role_id = '00000000-0000-0000-0000-000000000001' -- change to super_admin role (but not is_super_admin flag)
WHERE user_id = current_setting('test.carlos_id')::uuid
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  (SELECT updated_at FROM core.memberships
   WHERE user_id = current_setting('test.carlos_id')::uuid
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
  > current_setting('test.initial_ts')::timestamptz,
  'memberships.updated_at should be updated on change'
);

-- Restore role
UPDATE core.memberships
SET role_id = '00000000-0000-0000-0000-000000000002' -- manager
WHERE user_id = current_setting('test.carlos_id')::uuid
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ========================================
-- TEST: unit_memberships updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
  v_carlos_id UUID;
BEGIN
  v_carlos_id := test_helpers.get_test_user_id('carlos@test.bellaitalia.com');

  SELECT updated_at INTO v_initial_updated_at
  FROM core.unit_memberships
  WHERE user_id = v_carlos_id
    AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.unit_memberships
SET role_id = '00000000-0000-0000-0000-000000000003' -- change to team
WHERE user_id = current_setting('test.carlos_id')::uuid
  AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

SELECT ok(
  (SELECT updated_at FROM core.unit_memberships
   WHERE user_id = current_setting('test.carlos_id')::uuid
     AND unit_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
  > current_setting('test.initial_ts')::timestamptz,
  'unit_memberships.updated_at should be updated on change'
);

-- ========================================
-- TEST: users_meta updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
  v_maria_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');

  SELECT updated_at INTO v_initial_updated_at
  FROM core.users_meta
  WHERE id = v_maria_id;

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM set_config('test.maria_id', v_maria_id::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.users_meta
SET first_name = 'Maria Updated'
WHERE id = current_setting('test.maria_id')::uuid;

SELECT ok(
  (SELECT updated_at FROM core.users_meta WHERE id = current_setting('test.maria_id')::uuid)
  > current_setting('test.initial_ts')::timestamptz,
  'users_meta.updated_at should be updated on change'
);

-- ========================================
-- TEST: unit_meta updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM core.unit_meta
  WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.unit_meta
SET notes = 'Updated notes'
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01';

SELECT ok(
  (SELECT updated_at FROM core.unit_meta WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
  > current_setting('test.initial_ts')::timestamptz,
  'unit_meta.updated_at should be updated on change'
);

-- ========================================
-- TEST: platform_users updated_at trigger
-- ========================================
-- Switch to service role for platform schema tests (platform schema is locked down)
SELECT test_helpers.set_service_role();

DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM platform.platform_users
  WHERE id = '20000000-0000-0000-0000-000000000001';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE platform.platform_users
SET first_name = 'Sarah Updated'
WHERE id = '20000000-0000-0000-0000-000000000001';

SELECT ok(
  (SELECT updated_at FROM platform.platform_users WHERE id = '20000000-0000-0000-0000-000000000001')
  > current_setting('test.initial_ts')::timestamptz,
  'platform_users.updated_at should be updated on change'
);

-- ========================================
-- TEST: platform_settings updated_at trigger
-- ========================================
-- Use existing setting from fixtures
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM platform.platform_settings
  WHERE key = 'maintenance_mode';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE platform.platform_settings
SET value = '"true"'::jsonb
WHERE key = 'maintenance_mode';

SELECT ok(
  (SELECT updated_at FROM platform.platform_settings WHERE key = 'maintenance_mode')
  > current_setting('test.initial_ts')::timestamptz,
  'platform_settings.updated_at should be updated on change'
);

SELECT * FROM finish();

ROLLBACK;
