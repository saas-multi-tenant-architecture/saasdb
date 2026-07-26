-- 06_role_labels.sql
-- Purpose: Every function that projects a role to a user-facing surface must
-- return the role's display label (core.roles.description) alongside the stable
-- identifier (core.roles.name).
--
-- WHY this file exists: consumers cannot derive the label from the identifier.
-- super_admin's label is "Owner"; de-slugifying yields "Super Admin", a role
-- that does not exist in the product — and it is the highest-privilege role in
-- the system. Any consumer that derives rather than reads gets that one wrong.
--
-- One file rather than assertions scattered across five others, so the label
-- contract has a single home and a ninth function has an obvious place to land.

BEGIN;

SELECT plan(14);

-- ========================================
-- SETUP: an invitation carrying the manager role
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT * INTO v_result FROM public.create_invitation(
    'labeltest@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid  -- manager
  );
  PERFORM set_config('test.label_invitation_token', v_result.token, true);
END $$;

-- ========================================
-- public.list_invitations
-- ========================================
SELECT is(
  (SELECT role_label FROM public.list_invitations(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'labeltest@example.com'),
  'Location manager with administrative access to assigned units',
  'list_invitations returns the role label'
);

-- The identifier must survive unchanged — this is an additive column, not a
-- rename. Consumers key behaviour on the identifier.
SELECT is(
  (SELECT role_name FROM public.list_invitations(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'labeltest@example.com'),
  'manager',
  'list_invitations still returns the role identifier'
);

-- ========================================
-- public.get_invitation_details
-- ========================================
SELECT is(
  (SELECT role_label FROM public.get_invitation_details(
     current_setting('test.label_invitation_token'))),
  'Location manager with administrative access to assigned units',
  'get_invitation_details returns the role label'
);

SELECT is(
  (SELECT role_name FROM public.get_invitation_details(
     current_setting('test.label_invitation_token'))),
  'manager',
  'get_invitation_details still returns the role identifier'
);

-- ========================================
-- public.list_my_organizations  (acting user: maria, super_admin)
-- ========================================
-- NOTE: `description` here is the ORGANIZATION's description; `role_label` is
-- the ROLE's. Two different columns, distinctly aliased. Do not conflate them.
SELECT is(
  (SELECT role_label FROM public.list_my_organizations()
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
  'Organization owner with full administrative access',
  'list_my_organizations returns the role label'
);

SELECT is(
  (SELECT role FROM public.list_my_organizations()
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
  'super_admin',
  'list_my_organizations still returns the role identifier'
);

-- ========================================
-- public.get_user_organizations
-- ========================================
-- This function is literally RETURN QUERY SELECT * FROM list_my_organizations().
-- If its RETURNS TABLE did not gain role_label in the same position, this call
-- raises a structure mismatch. That failure happens at CALL time, not deploy
-- time — which is exactly why this assertion exists.
SELECT is(
  (SELECT role_label FROM public.get_user_organizations()
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
  'Organization owner with full administrative access',
  'get_user_organizations returns the role label through its delegate'
);

-- ========================================
-- public.list_organization_members
-- ========================================
-- The most important of the eight: this is the function that renders an
-- organisation's Owner. super_admin -> "Owner" is precisely the mapping no
-- consumer can derive, and invitations can never carry super_admin at all.
SELECT is(
  (SELECT role_label FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'maria@test.bellaitalia.com'),
  'Organization owner with full administrative access',
  'list_organization_members returns the label for the org owner'
);

SELECT is(
  (SELECT role_label FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'carlos@test.bellaitalia.com'),
  'Location manager with administrative access to assigned units',
  'list_organization_members returns the label for a manager'
);

-- ========================================
-- public.list_my_units  (self-scoped: must act as carlos)
-- ========================================
-- list_my_units filters on core.get_current_user_id(), so the acting user has
-- to be the one whose units we assert on. Carlos is manager at Downtown.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT is(
  (SELECT role_label FROM public.list_my_units()
   WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid),
  'Location manager with administrative access to assigned units',
  'list_my_units returns the role label'
);

-- ========================================
-- public.get_user_units
-- ========================================
SELECT is(
  (SELECT role_label FROM public.get_user_units(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid),
  'Location manager with administrative access to assigned units',
  'get_user_units returns the role label'
);

-- ========================================
-- public.list_unit_members
-- ========================================
-- Back to maria: unit_memberships_select allows any org member to read the
-- unit memberships of their org's units, and she is the org owner.
-- Sam is team at Downtown.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT role_label FROM public.list_unit_members(
     'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)
   WHERE email = 'sam@test.bellaitalia.com'),
  'Team member with read access and limited write access',
  'list_unit_members returns the role label'
);

-- ========================================
-- NULL passthrough
-- ========================================
-- core.roles.description is nullable and roles are seeded per deployment, so
-- NULL is a real state meaning "this deployment gave the role no label".
-- The functions must NOT COALESCE it to r.name: doing so would render
-- 'super_admin' to an end user in exactly the case nobody tests, which is the
-- original bug reappearing somewhere harder to find.
--
-- This UPDATE is safe: tests wrap in BEGIN/ROLLBACK, and nothing anywhere
-- asserts an exact core.roles count (only existence and > 0).
SELECT test_helpers.set_service_role();

UPDATE core.roles SET description = NULL WHERE name = 'manager';

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT role_label FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'carlos@test.bellaitalia.com'),
  NULL,
  'A role with no description yields NULL role_label, not the identifier'
);

-- The identifier must be unaffected by the missing label.
SELECT is(
  (SELECT role FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'carlos@test.bellaitalia.com'),
  'manager',
  'The role identifier is unaffected by a NULL label'
);

SELECT * FROM finish();

ROLLBACK;
