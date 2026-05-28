-- 04_graphql_exclusions.sql
-- Purpose: Verify the pg_graphql extension is disabled.
--
-- SMTA drops pg_graphql because Supabase enables it by default and it
-- auto-exposes core.* tables to the authenticated role via a generated
-- GraphQL schema (Supabase lint 0027). All access goes through public.*
-- RPC functions; no GraphQL surface is needed or supported.

BEGIN;

SELECT plan(1);

SELECT ok(
  NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_graphql'),
  'pg_graphql extension is not installed'
);

SELECT * FROM finish();
ROLLBACK;
