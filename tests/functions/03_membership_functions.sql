-- 03_membership_functions.sql
-- Purpose: Test public membership management functions

BEGIN;

SELECT plan(16);

-- ========================================
-- TEST: add_member_to_organization works
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- Store Maria's ID for use in inserts
DO $$
DECLARE
  v_maria_id UUID;
  v_new_user_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');
  -- Generate deterministic UUID for test user
  v_new_user_id := extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'newmember@test.com');
  PERFORM set_config('test.maria_id', v_maria_id::text, true);
  PERFORM set_config('test.new_user_id', v_new_user_id::text, true);
END $$;

-- Create a new test user (uses SECURITY DEFINER helper to bypass RLS on auth.users)
SELECT test_helpers.create_test_user('newmember@test.com', 'New', 'Member');

SELECT lives_ok(
  format(
    $$SELECT public.add_member_to_organization(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      %L,
      '00000000-0000-0000-0000-000000000003'
    )$$,
    current_setting('test.new_user_id')::uuid
  ),
  'add_member_to_organization should succeed'
);

-- Verify membership was created
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships
    WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      AND user_id = current_setting('test.new_user_id')::uuid
      AND is_super_admin = false
  ),
  'New member should have membership record'
);

-- ========================================
-- TEST: New member appears in list_organization_members
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = current_setting('test.new_user_id')::uuid
  ),
  'New member should appear in member list'
);

-- ========================================
-- TEST: update_member_role works
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.update_member_role(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      %L,
      '00000000-0000-0000-0000-000000000002'
    )$$,
    current_setting('test.new_user_id')::uuid
  ),
  'update_member_role should succeed'
);

SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = current_setting('test.new_user_id')::uuid),
  'manager',
  'Member role should be updated to manager'
);

-- ========================================
-- TEST: remove_member_from_organization soft-deletes
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.remove_member_from_organization(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      %L
    )$$,
    current_setting('test.new_user_id')::uuid
  ),
  'remove_member_from_organization should succeed'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = current_setting('test.new_user_id')::uuid
  ),
  'Removed member should not appear in member list'
);

-- Verify soft-delete (not hard delete) - use helper to bypass RLS which hides is_deleted=true rows
SELECT ok(
  test_helpers.membership_is_soft_deleted(
    current_setting('test.new_user_id')::uuid,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Membership should be soft-deleted'
);

-- ========================================
-- TEST: add_member_to_unit works
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.add_member_to_unit(
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
      %L,
      '00000000-0000-0000-0000-000000000003'
    )$$,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'add_member_to_unit should succeed'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'Taylor should appear in Downtown unit members'
);

-- ========================================
-- TEST: update_unit_member_role works
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.update_unit_member_role(
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
      %L,
      '00000000-0000-0000-0000-000000000002'
    )$$,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'update_unit_member_role should succeed'
);

SELECT is(
  (SELECT role FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
   WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')),
  'manager',
  'Taylor unit role should be updated to manager'
);

-- ========================================
-- TEST: remove_member_from_unit soft-deletes
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.remove_member_from_unit(
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
      %L
    )$$,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'remove_member_from_unit should succeed'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_unit_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'Taylor should not appear in Downtown unit members'
);

-- Verify unit membership soft-delete (not hard delete)
SELECT ok(
  test_helpers.unit_membership_is_soft_deleted(
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
  ),
  'Unit membership should be soft-deleted'
);

-- ========================================
-- TEST: Cannot remove super_admin from org
-- ========================================
SELECT throws_ok(
  format(
    $$SELECT public.remove_member_from_organization(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      %L
    )$$,
    test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Cannot soft-delete super_admin membership. Transfer super_admin status first.',
  'Cannot remove super_admin from organization'
);

SELECT * FROM finish();

ROLLBACK;
