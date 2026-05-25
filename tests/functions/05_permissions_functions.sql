-- 05_permissions_functions.sql
-- Purpose: Test public.get_user_permissions() and public.get_user_unit_permissions()
--
-- Fixtures used:
--   Pizza Palace  (cccccccc-cccc-cccc-cccc-cccccccccccc)
--     Luigi     -> super_admin
--     Giuseppe  -> team @ Main Street (dddddddd-dddd-dddd-dddd-dddddddddd01)
--
--   Bella Italia  (aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa)
--     Carlos    -> manager @ Downtown (bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01)
--     Alex      -> team @ Downtown, manager @ Mall (bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03)
--     Taylor    -> org member only (no unit memberships)

BEGIN;

SELECT plan(9);

-- ========================================
-- get_user_permissions(): org-level rules
-- ========================================

-- TEST 1: super_admin gets correct role_name
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT role_name FROM public.get_user_permissions('cccccccc-cccc-cccc-cccc-cccccccccccc')),
  'super_admin',
  'get_user_permissions should return super_admin role for Luigi'
);

-- TEST 2: super_admin casl_rules are not null
SELECT ok(
  (SELECT casl_rules FROM public.get_user_permissions('cccccccc-cccc-cccc-cccc-cccccccccccc')) IS NOT NULL,
  'get_user_permissions should return non-null casl_rules for Luigi'
);

-- TEST 3: team member gets correct role_name
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('giuseppe@test.pizzapalace.com'));

SELECT is(
  (SELECT role_name FROM public.get_user_permissions('cccccccc-cccc-cccc-cccc-cccccccccccc')),
  'team',
  'get_user_permissions should return team role for Giuseppe'
);

-- TEST 4: cross-org isolation — Luigi gets no rows for Bella Italia
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_permissions('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
  0,
  'get_user_permissions should return no rows for an org the user does not belong to'
);

-- ========================================
-- get_user_unit_permissions(): unit-level rules
-- ========================================

-- TEST 5: manager at a unit gets correct role_name
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT is(
  (SELECT role_name FROM public.get_user_unit_permissions('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')),
  'manager',
  'get_user_unit_permissions should return manager role for Carlos at Downtown'
);

-- TEST 6: unit casl_rules are not null
SELECT ok(
  (SELECT casl_rules FROM public.get_user_unit_permissions('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')) IS NOT NULL,
  'get_user_unit_permissions should return non-null casl_rules for Carlos at Downtown'
);

-- TEST 7: user with different roles at different units — team at Downtown
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('alex@test.bellaitalia.com'));

SELECT is(
  (SELECT role_name FROM public.get_user_unit_permissions('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')),
  'team',
  'get_user_unit_permissions should return team role for Alex at Downtown'
);

-- TEST 8: same user — manager at Mall
SELECT is(
  (SELECT role_name FROM public.get_user_unit_permissions('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03')),
  'manager',
  'get_user_unit_permissions should return manager role for Alex at Mall'
);

-- TEST 9: org member with no unit memberships gets no rows
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('taylor@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM public.get_user_unit_permissions('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01')),
  0,
  'get_user_unit_permissions should return no rows for a user with no unit membership'
);

SELECT * FROM finish();

ROLLBACK;
