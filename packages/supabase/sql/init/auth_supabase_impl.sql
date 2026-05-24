-- auth_supabase_impl.sql
-- Purpose: Supabase implementation of core.get_current_user_id().
-- Runs immediately after auth_interface.sql, replacing the stub.
-- In the future monorepo, this file lives in packages/supabase/.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, auth, public;
