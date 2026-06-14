-- auth_better_auth_impl.sql
-- Purpose: better-auth implementation of core.get_current_user_id().
-- Reads the user UUID from a PostgreSQL session variable set by the
-- withSMTA() transaction wrapper in @smta/better-auth.
-- Identical mechanism to @smta/payload — no Supabase dependency.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
