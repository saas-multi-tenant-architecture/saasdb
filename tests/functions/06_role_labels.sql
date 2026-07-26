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

SELECT plan(4);

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
  PERFORM set_config('test.label_invitation_token', v_result.token, false);
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

SELECT * FROM finish();

ROLLBACK;
