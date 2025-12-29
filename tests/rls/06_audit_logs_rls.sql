-- 06_audit_logs_rls.sql
-- Purpose: Verify RLS policies on core.audit_logs table

BEGIN;

-- Load fixtures
\i tests/fixtures/00_test_helpers.sql
\i tests/fixtures/01_roles.sql
\i tests/fixtures/02_test_users.sql
\i tests/fixtures/03_bella_italia.sql
\i tests/fixtures/04_pizza_palace.sql

SELECT plan(8);

-- ========================================
-- SETUP: Create some audit log entries
-- ========================================
INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
VALUES
  -- Bella Italia logs
  ('11111111-1111-1111-1111-111111111101', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'insert', 'core.units',
   'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', NULL, '{"name": "Downtown"}'),
  ('11111111-1111-1111-1111-111111111102', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'update', 'core.units',
   'aaaaaaaa-aaaa-aaaa-aaaa-000000000001', '{"name": "Old Name"}', '{"name": "Downtown"}'),
  -- Pizza Palace logs
  ('11111111-1111-1111-1111-111111111201', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'insert', 'core.units',
   'bbbbbbbb-bbbb-bbbb-bbbb-000000000001', NULL, '{"name": "Main Street"}');

-- ========================================
-- TEST: Org member can SELECT audit logs for their org
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111101'); -- Maria

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
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'Maria cannot see Pizza Palace audit logs'
);

-- ========================================
-- TEST: Super_admin can INSERT audit logs
-- ========================================
SELECT lives_ok(
  $$INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
    VALUES (
      '11111111-1111-1111-1111-111111111101',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'update',
      'core.organizations',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '{"name": "Old"}',
      '{"name": "New"}'
    )$$,
  'Maria can INSERT audit log entry'
);

-- ========================================
-- TEST: Regular member can INSERT audit logs (permissive)
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111102'); -- Carlos

SELECT lives_ok(
  $$INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
    VALUES (
      '11111111-1111-1111-1111-111111111102',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'update',
      'core.units',
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',
      '{"name": "Downtown"}',
      '{"name": "Downtown Updated"}'
    )$$,
  'Carlos can INSERT audit log entry'
);

-- ========================================
-- TEST: Cannot INSERT audit log for other org
-- ========================================
SELECT throws_ok(
  $$INSERT INTO core.audit_logs (actor_id, organization_id, action, target_table, target_id, old_values, new_values)
    VALUES (
      '11111111-1111-1111-1111-111111111102',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'update',
      'core.units',
      'bbbbbbbb-bbbb-bbbb-bbbb-000000000001',
      '{}',
      '{}'
    )$$,
  '42501', -- insufficient_privilege
  'Carlos cannot INSERT audit log for Pizza Palace'
);

-- ========================================
-- TEST: Regular member can view audit logs
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111106'); -- Sam

SELECT ok(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') > 0,
  'Sam (team member) can view audit logs'
);

-- ========================================
-- TEST: Pizza Palace isolation
-- ========================================
SELECT utils.set_auth_user('11111111-1111-1111-1111-111111111201'); -- Luigi

SELECT is(
  (SELECT COUNT(*)::int FROM core.audit_logs
   WHERE organization_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
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
