-- 02_cascading_deletes.sql
-- Purpose: Test soft-delete behaviors via public API functions
-- Note: Direct UPDATE SET is_deleted=true is blocked by RLS by design.
--       All soft-deletes must go through SECURITY DEFINER public API functions.

BEGIN;

SELECT plan(7);

-- ========================================
-- SETUP
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

-- ========================================
-- TEST: delete_unit hides unit from active queries
-- ========================================
DO $$
DECLARE v_maria_id UUID;
BEGIN
  v_maria_id := test_helpers.get_test_user_id('maria@test.bellaitalia.com');
  INSERT INTO core.units (id, organization_id, name, created_by, updated_by)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Temporary Unit',
    v_maria_id,
    v_maria_id
  );
END $$;

SELECT public.delete_unit('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99');

SELECT ok(
  NOT EXISTS (SELECT 1 FROM core.units WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99'),
  'Soft-deleted unit is hidden from active queries'
);

-- ========================================
-- TEST: Soft-deleted unit is physically preserved (via SECURITY DEFINER helper)
-- ========================================
SELECT ok(
  test_helpers.unit_is_soft_deleted('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb99'),
  'Soft-deleted unit still exists in database (is_deleted = true)'
);

-- ========================================
-- TEST: delete_unit cascades to unit_memberships
-- ========================================
-- Downtown has 4 unit_memberships (Carlos, Sofia, Alex, Sam)
SELECT public.delete_unit('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01');

-- Carlos had a Downtown membership; it should now be soft-deleted
SELECT ok(
  test_helpers.unit_membership_is_soft_deleted(
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'
  ),
  'delete_unit cascades soft-delete to unit_memberships'
);

-- ========================================
-- TEST: Soft-deleted member does not appear in org member list
-- ========================================
SELECT public.remove_member_from_organization(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.list_organization_members('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  ),
  'Removed member does not appear in org member list'
);

-- ========================================
-- TEST: Soft-deleted membership is physically preserved
-- ========================================
SELECT ok(
  test_helpers.membership_is_soft_deleted(
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'Soft-deleted membership still exists in database (is_deleted = true)'
);

-- ========================================
-- TEST: Cannot re-insert a soft-deleted membership (unique constraint)
-- ========================================
SELECT throws_ok(
  format($$INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
    VALUES (%L, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000003', false, %L, %L)$$,
    test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
    test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
    test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  '23505',
  NULL,
  'Cannot re-insert membership that was soft-deleted (unique constraint)'
);

-- ========================================
-- TEST: Org remains visible after member removal
-- ========================================
SELECT ok(
  EXISTS (SELECT 1 FROM core.organizations WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Organization remains visible after removing a member'
);

SELECT * FROM finish();

ROLLBACK;
