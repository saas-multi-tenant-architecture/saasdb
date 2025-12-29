-- 01_multi_org_user.sql
-- Purpose: Test edge cases for users belonging to multiple organizations

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql
\i tests/fixtures/04_pizza_palace.sql

SELECT plan(10);

-- ========================================
-- SETUP: Make Carlos a member of both orgs
-- ========================================
-- Carlos is already in Bella Italia, add him to Pizza Palace
INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
VALUES (
  '11111111-1111-1111-1111-111111111102', -- Carlos
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', -- Pizza Palace
  '00000000-0000-0000-0000-000000000003', -- team
  false,
  '11111111-1111-1111-1111-111111111201', -- Created by Luigi
  '11111111-1111-1111-1111-111111111201'
);

-- ========================================
-- TEST: User can see both organizations
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

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
   WHERE user_id = '11111111-1111-1111-1111-111111111102'),
  'manager',
  'Carlos is manager at Bella Italia'
);

SELECT is(
  (SELECT role FROM public.list_organization_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
   WHERE user_id = '11111111-1111-1111-1111-111111111102'),
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
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
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
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'$$,
  'Carlos can update Pizza Palace'
);

-- ========================================
-- TEST: Removing from one org doesn't affect other
-- ========================================
UPDATE core.memberships
SET is_deleted = true, deleted_at = now()
WHERE user_id = '11111111-1111-1111-1111-111111111102'
  AND organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

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
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
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
