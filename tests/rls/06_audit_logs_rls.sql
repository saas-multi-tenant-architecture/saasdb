-- 06_audit_logs_rls.sql
-- Purpose: Verify RLS policies on core.audit_logs table

BEGIN;

SELECT plan(5);

-- ========================================
-- SETUP: Clean slate and create known audit log entries
-- ========================================
DO $$
BEGIN
  -- Clear any leftover audit logs from previous test runs
  DELETE FROM core.audit_logs;
  -- Bella Italia logs
  PERFORM test_helpers.seed_audit_log(
    test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'core.units',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
    'insert',
    'Inserted Downtown unit'
  );

  PERFORM test_helpers.seed_audit_log(
    test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'core.units',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
    'update',
    'Updated Downtown unit name'
  );

  -- Pizza Palace log
  PERFORM test_helpers.seed_audit_log(
    test_helpers.get_test_user_id('luigi@test.pizzapalace.com'),
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'core.units',
    'dddddddd-dddd-dddd-dddd-dddddddddd01',
    'insert',
    'Inserted Main Street unit'
  );
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
