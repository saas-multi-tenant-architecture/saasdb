-- 01_organization_functions.sql
-- Purpose: Test public organization management functions

BEGIN;

SELECT plan(12);

-- ========================================
-- TEST: create_organization creates org with super_admin
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  $$SELECT public.create_organization('Test Restaurant', 'A test organization')$$,
  'create_organization should succeed'
);

-- Verify organization was created
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE name = 'Test Restaurant'
      AND created_by = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Organization should be created with correct name and creator'
);

-- ========================================
-- TEST: Creator becomes super_admin
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.memberships m
    JOIN core.organizations o ON o.id = m.organization_id
    WHERE o.name = 'Test Restaurant'
      AND m.user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
      AND m.is_super_admin = true
  ),
  'Creator should be super_admin of new organization'
);

-- ========================================
-- TEST: Creator has super_admin role
-- ========================================
SELECT is(
  (SELECT r.name FROM core.memberships m
   JOIN core.organizations o ON o.id = m.organization_id
   JOIN core.roles r ON r.id = m.role_id
   WHERE o.name = 'Test Restaurant'
     AND m.user_id = test_helpers.get_test_user_id('maria@test.bellaitalia.com')),
  'super_admin',
  'Creator should have super_admin role'
);

-- ========================================
-- TEST: organizations_meta is created automatically
-- ========================================
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations_meta om
    JOIN core.organizations o ON o.id = om.id
    WHERE o.name = 'Test Restaurant'
  ),
  'organizations_meta should be created for new org'
);

-- ========================================
-- TEST: get_organization returns correct data
-- ========================================
-- First get the org ID
DO $$
DECLARE
  v_org_id UUID;
BEGIN
  SELECT id INTO v_org_id FROM core.organizations WHERE name = 'Test Restaurant';
  PERFORM set_config('test.org_id', v_org_id::text, true);
END $$;

SELECT ok(
  (SELECT name FROM public.get_organization(current_setting('test.org_id')::uuid)) = 'Test Restaurant',
  'get_organization should return correct name'
);

SELECT ok(
  (SELECT description FROM public.get_organization(current_setting('test.org_id')::uuid)) = 'A test organization',
  'get_organization should return correct description'
);

-- ========================================
-- TEST: update_organization works
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.update_organization('%s'::uuid, 'Updated Restaurant', 'Updated description')$$,
    current_setting('test.org_id')
  ),
  'update_organization should succeed'
);

SELECT ok(
  (SELECT name FROM public.get_organization(current_setting('test.org_id')::uuid)) = 'Updated Restaurant',
  'Organization name should be updated'
);

-- ========================================
-- TEST: delete_organization soft-deletes
-- ========================================
SELECT lives_ok(
  format(
    $$SELECT public.delete_organization('%s'::uuid)$$,
    current_setting('test.org_id')
  ),
  'delete_organization should succeed'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = current_setting('test.org_id')::uuid
      AND is_deleted = true
      AND deleted_at IS NOT NULL
  ),
  'Organization should be soft-deleted'
);

-- ========================================
-- TEST: get_organization returns NULL for deleted org
-- ========================================
SELECT ok(
  (SELECT id FROM public.get_organization(current_setting('test.org_id')::uuid)) IS NULL,
  'get_organization should return NULL for deleted org'
);

SELECT * FROM finish();

ROLLBACK;
