-- 06_audit_logs_rls.sql
-- Purpose: Verify RLS policies on core.audit_logs table

BEGIN;

SELECT plan(8);

-- ========================================
-- SETUP: Create some audit log entries
-- ========================================
DO $$
BEGIN
  INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
  VALUES
    -- Bella Italia logs
    (test_helpers.get_test_user_id('maria@test.bellaitalia.com'), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'insert', 'core.units',
     'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', NULL, '{"name": "Downtown"}'),
    (test_helpers.get_test_user_id('carlos@test.bellaitalia.com'), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'update', 'core.units',
     'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', '{"name": "Old Name"}', '{"name": "Downtown"}'),
    -- Pizza Palace logs
    (test_helpers.get_test_user_id('luigi@test.pizzapalace.com'), 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'insert', 'core.units',
     'dddddddd-dddd-dddd-dddd-dddddddddd01', NULL, '{"name": "Main Street"}');
END $$;

-- ========================================
-- TEST: Org member can SELECT audit logs for their org
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  2,
  'Maria can see 2 Bella Italia audit logs'
);

-- ========================================
-- TEST: Cannot SELECT audit logs from other org
-- ========================================
SELECT is(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'Maria cannot see Pizza Palace audit logs'
);

-- ========================================
-- TEST: Super_admin can INSERT audit logs
-- ========================================
SELECT lives_ok(
  format(
    $$INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
      VALUES (
        %L,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'update',
        'core.organizations',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '{"name": "Old"}',
        '{"name": "New"}'
      )$$,
    test_helpers.get_test_user_id('maria@test.bellaitalia.com')
  ),
  'Maria can INSERT audit log entry'
);

-- ========================================
-- TEST: Regular member can INSERT audit logs (permissive)
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT lives_ok(
  format(
    $$INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
      VALUES (
        %L,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'update',
        'core.units',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
        '{"name": "Downtown"}',
        '{"name": "Downtown Updated"}'
      )$$,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  'Carlos can INSERT audit log entry'
);

-- ========================================
-- TEST: Cannot INSERT audit log for other org
-- ========================================
SELECT throws_ok(
  format(
    $$INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
      VALUES (
        %L,
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'update',
        'core.units',
        'dddddddd-dddd-dddd-dddd-dddddddddd01',
        '{}',
        '{}'
      )$$,
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com')
  ),
  '42501', -- insufficient_privilege
  NULL,
  'Carlos cannot INSERT audit log for Pizza Palace'
);

-- ========================================
-- TEST: Regular member can view audit logs
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('sam@test.bellaitalia.com'));

SELECT ok(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') > 0,
  'Sam (team member) can view audit logs'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('luigi@test.pizzapalace.com'));

SELECT is(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  1,
  'Luigi can see 1 Pizza Palace audit log'
);

SELECT is(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'Luigi cannot see Bella Italia audit logs'
);

SELECT * FROM finish();

ROLLBACK;
