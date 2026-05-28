-- exclusions.sql
-- Purpose: Hide core.* tables from the pg_graphql-generated GraphQL schema.
--
-- Design context:
--   - Every public-facing operation must go through public.* RPC functions.
--   - core.* tables retain SELECT for authenticated because SECURITY INVOKER
--     functions need it; RLS policies are the row-level access gateway.
--   - Without these comments, pg_graphql would auto-expose core.* tables to
--     authenticated users in the GraphQL schema (Supabase lint 0027). RLS
--     would still protect the data, but exposing the schema is unnecessary
--     and inconsistent with the function-first API design.
--
-- Mechanism:
--   pg_graphql reads COMMENT ON TABLE directives. A JSON payload of
--   {"expose": false} tells the extension to skip the table when building
--   the GraphQL schema. The table remains fully usable via SQL and via
--   SECURITY INVOKER functions; only the GraphQL surface is suppressed.
--
-- Platform tables (platform.*) are NOT listed here because Task 2
-- (platform grants) revokes all authenticated access at the schema level,
-- which already removes them from pg_graphql.

COMMENT ON TABLE core.organizations       IS '@graphql({"expose": false})';
COMMENT ON TABLE core.organizations_meta  IS '@graphql({"expose": false})';
COMMENT ON TABLE core.units               IS '@graphql({"expose": false})';
COMMENT ON TABLE core.unit_meta           IS '@graphql({"expose": false})';
COMMENT ON TABLE core.memberships         IS '@graphql({"expose": false})';
COMMENT ON TABLE core.unit_memberships    IS '@graphql({"expose": false})';
COMMENT ON TABLE core.users_meta          IS '@graphql({"expose": false})';
COMMENT ON TABLE core.audit_logs          IS '@graphql({"expose": false})';
COMMENT ON TABLE core.organization_files  IS '@graphql({"expose": false})';
COMMENT ON TABLE core.invitations         IS '@graphql({"expose": false})';
COMMENT ON TABLE core.roles               IS '@graphql({"expose": false})';
