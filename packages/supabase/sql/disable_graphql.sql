-- disable_extension.sql
-- Purpose: Drop the pg_graphql extension.
--
-- Supabase enables pg_graphql by default, which auto-exposes tables accessible
-- to the authenticated role in a generated GraphQL schema (Supabase lint 0027).
-- SMTA uses RLS + public.* RPC functions as the only access surface; there is
-- no GraphQL layer, so the extension provides no value and introduces unnecessary
-- schema exposure.
--
-- IF EXISTS makes this safe to run on environments where the extension is already
-- absent (non-Supabase deployments, custom Postgres instances, etc.).

DROP EXTENSION IF EXISTS pg_graphql;
