-- 04_graphql_exclusions.sql
-- Purpose: Verify all 11 core.* tables carry the pg_graphql exclusion comment
-- so they do not appear in the generated GraphQL schema.

BEGIN;

SELECT plan(11);

SELECT is(
  obj_description('core.audit_logs'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.audit_logs is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.invitations'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.invitations is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.memberships'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.memberships is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.organization_files'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.organization_files is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.organizations'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.organizations is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.organizations_meta'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.organizations_meta is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.roles'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.roles is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.unit_memberships'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.unit_memberships is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.unit_meta'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.unit_meta is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.units'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.units is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.users_meta'::regclass, 'pg_class'),
  '@graphql({"expose": false})',
  'core.users_meta is excluded from pg_graphql'
);

SELECT * FROM finish();
ROLLBACK;
