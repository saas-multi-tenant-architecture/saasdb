-- 01_multi_org_user.sql
-- Purpose: Test edge cases for users belonging to multiple organizations

BEGIN;

SELECT plan(10);

-- ========================================
-- SETUP: Make Carlos a member of both orgs
-- ========================================
-- Carlos is already in Bella Italia, add him to Pizza Palace
DO $$
BEGIN
  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
  VALUES (
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    'cccccccc-cccc-cccc-cccc-cccccccccccc', -- Pizza Palace
    '00000000-0000-0000-0000-000000000003', -- team
    false,
    test_helpers.get_test_user_id('luigi@test.pizzapalace.com'),
    test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
  );
END $$;

-- ========================================
-- TEST: User can see both organizations
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_organizations()),
  2,
  'Carlos should belong to 2 organizations'
);

-- ========================================
-- TEST: User has different roles in different orgs
-- ========================================
SELECT is(
  (SELECT role FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
   WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')),
  'manager',
  'Carlos is manager at Bella Italia'
);

SELECT is(
  (SELECT role FROM public.list_organization_members('cccccccc-cccc-cccc-cccc-cccccccccccc')
   WHERE user_id = test_helpers.get_test_user_id('carlos@test.bellaitalia.com')),
  'team',
  'Carlos is team at Pizza Palace'
);

-- ========================================
-- TEST: User can view data from both orgs
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Carlos can see Bella Italia'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'Carlos can see Pizza Palace'
);

-- ========================================
-- TEST: User can only modify data for orgs they belong to
-- ========================================
SELECT lives_ok(
  $$UPDATE core.organizations
    SET description = 'Updated by Carlos'
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
  'Carlos can update Bella Italia'
);

SELECT lives_ok(
  $$UPDATE core.organizations
    SET description = 'Updated by Carlos'
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'$$,
  'Carlos can update Pizza Palace'
);

-- ========================================
-- TEST: Removing from one org doesn't affect other
-- ========================================
-- Switch to Luigi (super_admin of Pizza Palace) to remove Carlos
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));
SELECT public.remove_member_from_organization(
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
);
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

-- Carlos can still see Bella Italia
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Carlos can still see Bella Italia after leaving Pizza Palace'
);

-- Carlos cannot see Pizza Palace anymore
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  ),
  'Carlos cannot see Pizza Palace after being removed'
);

-- Only 1 org now
SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_organizations()),
  1,
  'Carlos should belong to 1 organization after removal'
);

SELECT * FROM finish();

ROLLBACK;
