-- 02_platform_users.sql
-- Purpose: Test platform user management functions

BEGIN;

SELECT plan(9);

-- Sarah's JWT identity drives SECURITY DEFINER functions (create/update/delete),
-- but direct SELECTs on platform.platform_users require service_role because
-- authenticated has no direct grants on platform tables.
-- ORDER MATTERS: set_auth_user sets role=authenticated as a side effect,
-- so set_service_role MUST come after it to override the role back to service_role.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sarah@pizzatech-saas.com'));
SELECT test_helpers.set_service_role();

-- ========================================
-- TEST: Platform users exist
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM platform.platform_users WHERE is_deleted = false),
  2,
  'Should have 2 active platform users'
);

-- ========================================
-- TEST: Sarah is platform super admin
-- ========================================
SELECT is(
  (SELECT pr.name FROM platform.platform_users pu
   JOIN platform.platform_roles pr ON pr.id = pu.role_id
   WHERE pu.supabase_user_id = test_helpers.get_test_user_id('sarah@pizzatech-saas.com')),
  'super_admin',
  'Sarah should be super_admin'
);

-- ========================================
-- TEST: Mike is platform viewer
-- ========================================
SELECT is(
  (SELECT pr.name FROM platform.platform_users pu
   JOIN platform.platform_roles pr ON pr.id = pu.role_id
   WHERE pu.supabase_user_id = test_helpers.get_test_user_id('mike@pizzatech-saas.com')),
  'platform_viewer',
  'Mike should be platform_viewer'
);

-- ========================================
-- TEST: create_platform_user function
-- ========================================
-- Reassert sarah's JWT + service_role for the subsequent function call and
-- direct state inspection.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sarah@pizzatech-saas.com'));
SELECT test_helpers.set_service_role();

SELECT lives_ok(
  format(
    $$SELECT platform.create_platform_user(
      %L,
      'sofia@bellaitalia.com',
      '10000000-0000-0000-0000-000000000003'
    )$$,
    test_helpers.get_test_user_id('sofia@test.bellaitalia.com')
  ),
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
