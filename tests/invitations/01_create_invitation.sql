-- 01_create_invitation.sql
-- Purpose: Test invitation creation functionality

BEGIN;

SELECT plan(14);

-- ========================================
-- TEST: Organization member can create invitation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT lives_ok(
  $$SELECT * FROM public.create_invitation(
    'newuser@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  'Maria can create an invitation to Bella Italia'
);

-- ========================================
-- TEST: Invitation is created with correct data
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM core.invitations
   WHERE email = 'newuser@example.com'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND status = 'pending'
     AND is_deleted = false),
  1,
  'Invitation record created in database'
);

-- ========================================
-- TEST: Token is generated and unique
-- ========================================
SELECT ok(
  (SELECT token IS NOT NULL AND length(token) > 20
   FROM core.invitations
   WHERE email = 'newuser@example.com'
     AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND is_deleted = false
   LIMIT 1),
  'Invitation has a secure token'
);

-- ========================================
-- TEST: Email is normalized to lowercase
-- ========================================
SELECT lives_ok(
  $$SELECT * FROM public.create_invitation(
    'UPPERCASE@EXAMPLE.COM',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  'Can create invitation with uppercase email'
);

SELECT is(
  (SELECT email FROM core.invitations
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND email LIKE '%uppercase%'
     AND is_deleted = false
   LIMIT 1),
  'uppercase@example.com',
  'Email is normalized to lowercase'
);

-- ========================================
-- TEST: Cannot create duplicate pending invitation
-- ========================================
SELECT throws_ok(
  $$SELECT * FROM public.create_invitation(
    'newuser@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  'A pending invitation to this email already exists for this organization',
  'Cannot create duplicate pending invitation'
);

-- ========================================
-- TEST: Non-member cannot create invitation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT throws_ok(
  $$SELECT * FROM public.create_invitation(
    'another@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  'You must be a member of this organization to invite users',
  'Non-member cannot create invitation'
);

-- ========================================
-- TEST: Cannot invite as super_admin
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT throws_ok(
  $$SELECT * FROM public.create_invitation(
    'trytobe@superadmin.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid
  )$$,
  'Cannot invite users as super_admin. Use public.transfer_super_admin() to transfer ownership.',
  'Cannot invite as super_admin'
);

-- ========================================
-- TEST: Cannot invite to unit without unit membership
-- ========================================
SELECT throws_ok(
  $$SELECT * FROM public.create_invitation(
    'unit@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid
  )$$,
  'You must be a member of this unit to invite users to it',
  'Cannot invite to unit without unit membership'
);

-- ========================================
-- TEST: Regular member can also create invitations (CASL controls this)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT lives_ok(
  $$SELECT * FROM public.create_invitation(
    'frommanager@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid
  )$$,
  'Manager can create invitation (CASL controls role permissions)'
);

-- ========================================
-- TEST: Invitation expires in 7 days
-- ========================================
SELECT ok(
  (SELECT expires_at > now() + INTERVAL '6 days'
     AND expires_at < now() + INTERVAL '8 days'
   FROM core.invitations
   WHERE email = 'frommanager@example.com'
     AND is_deleted = false
   LIMIT 1),
  'Invitation expires in approximately 7 days'
);

-- ========================================
-- TEST: Cannot invite existing member
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT throws_ok(
  $$SELECT * FROM public.create_invitation(
    'carlos@test.bellaitalia.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  'This user is already a member of the organization',
  'Cannot invite existing member'
);

-- ========================================
-- TEST: Metadata can be included
-- ========================================
SELECT lives_ok(
  $$SELECT * FROM public.create_invitation(
    'metadata@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    NULL,
    '{"message": "Welcome!", "source": "dashboard"}'::jsonb
  )$$,
  'Can create invitation with metadata'
);

SELECT is(
  (SELECT metadata->>'message' FROM core.invitations
   WHERE email = 'metadata@example.com'
     AND is_deleted = false
   LIMIT 1),
  'Welcome!',
  'Metadata is stored correctly'
);

SELECT * FROM finish();

ROLLBACK;
