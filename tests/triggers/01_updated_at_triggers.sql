-- 01_updated_at_triggers.sql
-- Purpose: Test that updated_at triggers work correctly

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql

SELECT plan(8);

-- ========================================
-- TEST: organizations updated_at trigger
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

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
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.units
SET description = 'Updated to test trigger'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

SELECT ok(
  (SELECT updated_at FROM core.units WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
  > current_setting('test.initial_ts')::timestamptz,
  'units.updated_at should be updated on change'
);

-- ========================================
-- TEST: memberships updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM core.memberships
  WHERE user_id = '11111111-1111-1111-1111-111111111102'
    AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.memberships
SET role_id = '00000000-0000-0000-0000-000000000001' -- change to super_admin role (but not is_super_admin flag)
WHERE user_id = '11111111-1111-1111-1111-111111111102'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

SELECT ok(
  (SELECT updated_at FROM core.memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111102'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
  > current_setting('test.initial_ts')::timestamptz,
  'memberships.updated_at should be updated on change'
);

-- Restore role
UPDATE core.memberships
SET role_id = '00000000-0000-0000-0000-000000000002' -- manager
WHERE user_id = '11111111-1111-1111-1111-111111111102'
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ========================================
-- TEST: unit_memberships updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM core.unit_memberships
  WHERE user_id = '11111111-1111-1111-1111-111111111102'
    AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.unit_memberships
SET role_id = '00000000-0000-0000-0000-000000000003' -- change to team
WHERE user_id = '11111111-1111-1111-1111-111111111102'
  AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

SELECT ok(
  (SELECT updated_at FROM core.unit_memberships
   WHERE user_id = '11111111-1111-1111-1111-111111111102'
     AND unit_id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
  > current_setting('test.initial_ts')::timestamptz,
  'unit_memberships.updated_at should be updated on change'
);

-- ========================================
-- TEST: users_meta updated_at trigger
-- ========================================
DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM core.users_meta
  WHERE id = '11111111-1111-1111-1111-111111111101';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.users_meta
SET first_name = 'Maria Updated'
WHERE id = '11111111-1111-1111-1111-111111111101';

SELECT ok(
  (SELECT updated_at FROM core.users_meta WHERE id = '11111111-1111-1111-1111-111111111101')
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
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE core.unit_meta
SET notes = 'Updated notes'
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001';

SELECT ok(
  (SELECT updated_at FROM core.unit_meta WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
  > current_setting('test.initial_ts')::timestamptz,
  'unit_meta.updated_at should be updated on change'
);

-- ========================================
-- TEST: platform_users updated_at trigger
-- ========================================
-- Create a platform user first
INSERT INTO platform.platform_users (id, supabase_user_id, email, role_id, created_by, updated_by)
VALUES (
  '22222222-2222-2222-2222-222222222201',
  '11111111-1111-1111-1111-111111111101',
  'platform-test@test.com',
  (SELECT id FROM platform.platform_roles WHERE name = 'platform_viewer'),
  '11111111-1111-1111-1111-111111111101',
  '11111111-1111-1111-1111-111111111101'
);

DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM platform.platform_users
  WHERE id = '22222222-2222-2222-2222-222222222201';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE platform.platform_users
SET email = 'platform-updated@test.com'
WHERE id = '22222222-2222-2222-2222-222222222201';

SELECT ok(
  (SELECT updated_at FROM platform.platform_users WHERE id = '22222222-2222-2222-2222-222222222201')
  > current_setting('test.initial_ts')::timestamptz,
  'platform_users.updated_at should be updated on change'
);

-- ========================================
-- TEST: platform_settings updated_at trigger
-- ========================================
INSERT INTO platform.platform_settings (key, value, created_by, updated_by)
VALUES ('test_key', '"test_value"', '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101');

DO $$
DECLARE
  v_initial_updated_at TIMESTAMPTZ;
BEGIN
  SELECT updated_at INTO v_initial_updated_at
  FROM platform.platform_settings
  WHERE key = 'test_key';

  PERFORM set_config('test.initial_ts', v_initial_updated_at::text, true);
  PERFORM pg_sleep(0.1);
END $$;

UPDATE platform.platform_settings
SET value = '"updated_value"'
WHERE key = 'test_key';

SELECT ok(
  (SELECT updated_at FROM platform.platform_settings WHERE key = 'test_key')
  > current_setting('test.initial_ts')::timestamptz,
  'platform_settings.updated_at should be updated on change'
);

SELECT * FROM finish();

ROLLBACK;
