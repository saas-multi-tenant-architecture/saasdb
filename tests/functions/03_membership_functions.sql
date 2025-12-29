-- 03_membership_functions.sql
-- Purpose: Test public membership management functions

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql
\i tests/fixtures/04_pizza_palace.sql

SELECT plan(16);

-- ========================================
-- TEST: add_member_to_organization works
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

-- Create a new test user
INSERT INTO auth.users (id, email) VALUES ('11111111-1111-1111-1111-111111111199', 'newmember@test.com');
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES ('11111111-1111-1111-1111-111111111199', 'newmember@test.com', 'New', 'Member',
        '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101');

SELECT lives_ok(
  $$SELECT public.add_member_to_organization(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111199',
    '00000000-0000-0000-0000-000000000003' -- team role
  )$$,
  'add_member_to_organization should succeed'
);

-- Verify membership was created
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships
    WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      AND user_id = '11111111-1111-1111-1111-111111111199'
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
    WHERE user_id = '11111111-1111-1111-1111-111111111199'
  ),
  'New member should appear in member list'
);

-- ========================================
-- TEST: update_member_role works
-- ========================================
SELECT lives_ok(
  $$SELECT public.update_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111199',
    '00000000-0000-0000-0000-000000000002' -- manager role
  )$$,
  'update_member_role should succeed'
);

SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = '11111111-1111-1111-1111-111111111199'),
  'manager',
  'Member role should be updated to manager'
);

-- ========================================
-- TEST: remove_member_from_organization soft-deletes
-- ========================================
SELECT lives_ok(
  $$SELECT public.remove_member_from_organization(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111199'
  )$$,
  'remove_member_from_organization should succeed'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = '11111111-1111-1111-1111-111111111199'
  ),
  'Removed member should not appear in member list'
);

-- Verify soft-delete (not hard delete)
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships
    WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      AND user_id = '11111111-1111-1111-1111-111111111199'
      AND is_deleted = true
  ),
  'Membership should be soft-deleted'
);

-- ========================================
-- TEST: add_member_to_unit works
-- ========================================
SELECT lives_ok(
  $$SELECT public.add_member_to_unit(
    'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', -- Downtown
    '11111111-1111-1111-1111-111111111107', -- Taylor (org member, no units)
    '00000000-0000-0000-0000-000000000003'  -- team role
  )$$,
  'add_member_to_unit should succeed'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
  ),
  'Taylor should appear in Downtown unit members'
);

-- ========================================
-- TEST: update_unit_member_role works
-- ========================================
SELECT lives_ok(
  $$SELECT public.update_unit_member_role(
    'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', -- Downtown
    '11111111-1111-1111-1111-111111111107', -- Taylor
    '00000000-0000-0000-0000-000000000002'  -- manager role
  )$$,
  'update_unit_member_role should succeed'
);

SELECT is(
  (SELECT role FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
   WHERE user_id = '11111111-1111-1111-1111-111111111107'),
  'manager',
  'Taylor unit role should be updated to manager'
);

-- ========================================
-- TEST: remove_member_from_unit soft-deletes
-- ========================================
SELECT lives_ok(
  $$SELECT public.remove_member_from_unit(
    'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', -- Downtown
    '11111111-1111-1111-1111-111111111107'  -- Taylor
  )$$,
  'remove_member_from_unit should succeed'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_unit_members('aaaaaaaa-aaaa-aaaa-aaaa-000000000001')
    WHERE user_id = '11111111-1111-1111-1111-111111111107'
  ),
  'Taylor should not appear in Downtown unit members'
);

-- ========================================
-- TEST: Cannot remove super_admin from org
-- ========================================
SELECT throws_ok(
  $$SELECT public.remove_member_from_organization(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '11111111-1111-1111-1111-111111111101' -- Maria (super_admin)
  )$$,
  'Cannot soft-delete super_admin membership. Transfer super_admin status first.',
  'Cannot remove super_admin from organization'
);

SELECT * FROM finish();

ROLLBACK;
