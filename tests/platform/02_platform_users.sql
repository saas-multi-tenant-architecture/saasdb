-- 02_platform_users.sql
-- Purpose: Test platform user management functions

BEGIN;

SELECT plan(10);

-- ========================================
-- TEST: Platform users exist
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.platform_users WHERE is_deleted = false),
  2,
  'Should have 2 active platform users'
);

-- ========================================
-- TEST: Maria is platform super admin
-- ========================================
SELECT is(
  (SELECT pr.name FROM platform.platform_users pu
   JOIN platform.platform_roles pr ON pr.id = pu.role_id
   WHERE pu.supabase_user_id = '11111111-1111-1111-1111-111111111101'),
  'platform_super_admin',
  'Maria should be platform_super_admin'
);

-- ========================================
-- TEST: Carlos is platform viewer
-- ========================================
SELECT is(
  (SELECT pr.name FROM platform.platform_users pu
   JOIN platform.platform_roles pr ON pr.id = pu.role_id
   WHERE pu.supabase_user_id = '11111111-1111-1111-1111-111111111102'),
  'platform_viewer',
  'Carlos should be platform_viewer'
);

-- ========================================
-- TEST: create_platform_user function
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria (platform super admin)

SELECT lives_ok(
  $$SELECT platform.create_platform_user(
    '11111111-1111-1111-1111-111111111103',
    'sofia@bellaitalia.com',
    '10000000-0000-0000-0000-000000000003' -- platform_viewer
  )$$,
  'Platform super admin can create platform user'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM platform.platform_users
    WHERE email = 'sofia@bellaitalia.com'
      AND is_deleted = false
  ),
  'New platform user should exist'
);

-- ========================================
-- TEST: update_platform_user function
-- ========================================
DO $$
DECLARE
  v_user_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM platform.platform_users WHERE email = 'sofia@bellaitalia.com';
  PERFORM set_config('test.platform_user_id', v_user_id::text, true);
END $$;

SELECT lives_ok(
  format(
    $$SELECT platform.update_platform_user(
      '%s'::uuid,
      '10000000-0000-0000-0000-000000000002' -- upgrade to platform_admin
    )$$,
    current_setting('test.platform_user_id')
  ),
  'Platform super admin can update platform user role'
);

SELECT is(
  (SELECT pr.name FROM platform.platform_users pu
   JOIN platform.platform_roles pr ON pr.id = pu.role_id
   WHERE pu.id = current_setting('test.platform_user_id')::uuid),
  'platform_admin',
  'Platform user role should be updated'
);

-- ========================================
-- TEST: delete_platform_user function (soft delete)
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT platform.delete_platform_user('%s'::uuid)$$,
    current_setting('test.platform_user_id')
  ),
  'Platform super admin can delete platform user'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM platform.platform_users
    WHERE id = current_setting('test.platform_user_id')::uuid
      AND is_deleted = true
      AND deleted_at IS NOT NULL
  ),
  'Platform user should be soft-deleted'
);

SELECT * FROM finish();

ROLLBACK;
