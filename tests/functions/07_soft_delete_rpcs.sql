-- 07_soft_delete_rpcs.sql
-- Purpose: Cover the non-privileged (assign/remove) unit and organization RPCs
-- and the soft-delete path they depend on.
--
-- These functions previously had no test coverage at all, which is why two
-- classes of defect shipped:
--
--   1. remove_user_from_unit, remove_user_from_organization and delete_file ran
--      as SECURITY INVOKER. Setting is_deleted = true produces a row that fails
--      the table's SELECT policy (which filters is_deleted = false), and Postgres
--      refuses an UPDATE whose new row the caller could not read back. The calls
--      could never succeed for any caller.
--   2. delete_unit was SECURITY DEFINER with no authorization check at all, so a
--      caller from any organization could destroy another tenant's unit.
--
-- IMPORTANT: a test for the soft-delete path must assert both that the target
-- was live beforehand AND that it is soft-deleted afterwards. Asserting only
-- "the call did not raise" passes vacuously when RLS matches zero rows.

BEGIN;

SELECT plan(21);

-- ========================================
-- IDs under test
-- ========================================
DO $$
BEGIN
  PERFORM set_config('test.maria',  test_helpers.get_test_user_id('maria@test.bellaitalia.com')::text,  true);
  PERFORM set_config('test.carlos', test_helpers.get_test_user_id('carlos@test.bellaitalia.com')::text, true);
  PERFORM set_config('test.sam',    test_helpers.get_test_user_id('sam@test.bellaitalia.com')::text,    true);
  PERFORM set_config('test.taylor', test_helpers.get_test_user_id('taylor@test.bellaitalia.com')::text, true);
  PERFORM set_config('test.luigi',  test_helpers.get_test_user_id('luigi@test.pizzapalace.com')::text,  true);
END $$;

-- Seed an organization file for the delete_file tests (no fixture provides one).
SELECT test_helpers.set_service_role();
INSERT INTO core.organization_files (id, file_url, file_type, organization_id, created_by)
VALUES (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01'::uuid,
  'https://example.test/menu.pdf',
  'application/pdf',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- ========================================
-- Finding 1: remove_user_from_unit is reachable
-- ========================================
SELECT test_helpers.set_auth_user(current_setting('test.maria')::uuid);

-- Precondition: Sam's Downtown membership is live. Without this the next
-- assertion could pass vacuously.
SELECT ok(
  NOT test_helpers.unit_membership_is_soft_deleted(
    current_setting('test.sam')::uuid,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid
  ),
  'Precondition: Sam has a live Downtown unit membership'
);

SELECT lives_ok(
  format(
    $$SELECT public.remove_user_from_unit(%L::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)$$,
    current_setting('test.sam')
  ),
  'remove_user_from_unit should succeed for a super_admin'
);

SELECT ok(
  test_helpers.unit_membership_is_soft_deleted(
    current_setting('test.sam')::uuid,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid
  ),
  'remove_user_from_unit should soft-delete the membership row'
);

-- ========================================
-- Finding 3: a removed member can be re-added
-- ========================================
-- The (user_id, unit_id) unique constraint still holds the tombstone, so a bare
-- INSERT raises a duplicate key error. assign_user_to_unit must reactivate it.
SELECT lives_ok(
  format(
    $$SELECT public.assign_user_to_unit(%L::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '00000000-0000-0000-0000-000000000003'::uuid)$$,
    current_setting('test.sam')
  ),
  'assign_user_to_unit should re-add a previously removed member'
);

SELECT ok(
  NOT test_helpers.unit_membership_is_soft_deleted(
    current_setting('test.sam')::uuid,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid
  ),
  'Re-adding should reactivate the tombstoned membership'
);

-- ========================================
-- The non-privileged path works without super_admin
-- ========================================
SELECT test_helpers.set_auth_user(current_setting('test.carlos')::uuid);

SELECT lives_ok(
  format(
    $$SELECT public.remove_user_from_unit(%L::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)$$,
    current_setting('test.sam')
  ),
  'remove_user_from_unit should succeed for an ordinary org member'
);

-- ========================================
-- Finding 4: the target must belong to the organization
-- ========================================
SELECT test_helpers.set_auth_user(current_setting('test.maria')::uuid);

SELECT throws_ok(
  format(
    $$SELECT public.assign_user_to_unit(%L::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '00000000-0000-0000-0000-000000000003'::uuid)$$,
    current_setting('test.luigi')
  ),
  'User is not a member of the organization',
  'assign_user_to_unit should reject a user from another organization'
);

-- ========================================
-- Finding 2: delete_unit requires authorization
-- ========================================
SELECT test_helpers.set_auth_user(current_setting('test.luigi')::uuid);

SELECT throws_ok(
  $$SELECT public.delete_unit('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)$$,
  'Unit not found',
  'delete_unit should refuse a caller from another organization'
);

SELECT ok(
  NOT test_helpers.unit_is_soft_deleted('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid),
  'A cross-tenant delete_unit must leave the unit intact'
);

SELECT test_helpers.set_auth_user(current_setting('test.carlos')::uuid);

SELECT throws_ok(
  $$SELECT public.delete_unit('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)$$,
  'Only a super_admin can delete a unit',
  'delete_unit should refuse an ordinary org member'
);

SELECT test_helpers.set_auth_user(current_setting('test.maria')::uuid);

SELECT lives_ok(
  $$SELECT public.delete_unit('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid)$$,
  'delete_unit should succeed for the org super_admin'
);

SELECT ok(
  test_helpers.unit_is_soft_deleted('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid),
  'delete_unit should soft-delete the unit'
);

-- ========================================
-- Finding 1: remove_user_from_organization is reachable
-- ========================================
SELECT ok(
  NOT test_helpers.membership_is_soft_deleted(
    current_setting('test.taylor')::uuid,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  'Precondition: Taylor has a live organization membership'
);

SELECT lives_ok(
  format(
    $$SELECT public.remove_user_from_organization(%L::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)$$,
    current_setting('test.taylor')
  ),
  'remove_user_from_organization should succeed'
);

SELECT ok(
  test_helpers.membership_is_soft_deleted(
    current_setting('test.taylor')::uuid,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  'remove_user_from_organization should soft-delete the membership row'
);

-- The protect_super_admin trigger still guards the owner.
SELECT throws_ok(
  format(
    $$SELECT public.remove_user_from_organization(%L::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)$$,
    current_setting('test.maria')
  ),
  'Cannot soft-delete super_admin membership. Transfer super_admin status first.',
  'remove_user_from_organization must not remove the super_admin'
);

-- ========================================
-- Cross-tenant negatives for the remaining functions
-- ========================================
SELECT test_helpers.set_auth_user(current_setting('test.luigi')::uuid);

SELECT throws_ok(
  format(
    $$SELECT public.remove_user_from_organization(%L::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)$$,
    current_setting('test.sam')
  ),
  'Organization not found',
  'remove_user_from_organization should refuse a caller from another organization'
);

SELECT throws_ok(
  format(
    $$SELECT public.remove_user_from_unit(%L::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)$$,
    current_setting('test.sam')
  ),
  'Unit not found',
  'remove_user_from_unit should refuse a caller from another organization'
);

-- ========================================
-- Finding 1: delete_file is reachable
-- ========================================
SELECT throws_ok(
  $$SELECT public.delete_file('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01'::uuid)$$,
  'File not found',
  'delete_file should refuse a caller from another organization'
);

SELECT test_helpers.set_auth_user(current_setting('test.maria')::uuid);

SELECT lives_ok(
  $$SELECT public.delete_file('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01'::uuid)$$,
  'delete_file should succeed for an org member'
);

-- Read the tombstone with RLS bypassed: the organization_files SELECT policy
-- filters is_deleted = false, so a soft-deleted row is invisible to the
-- 'authenticated' role that set_auth_user() switches to.
SELECT test_helpers.set_service_role();

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organization_files
    WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01'::uuid
      AND is_deleted = true
  ),
  'delete_file should soft-delete the file row'
);

SELECT * FROM finish();

ROLLBACK;
