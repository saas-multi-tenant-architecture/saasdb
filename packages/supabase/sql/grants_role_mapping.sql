-- grants_role_mapping.sql
-- Purpose: Map SMTA core's neutral roles onto Supabase's GoTrue roles so that
-- privileges granted to app_user/app_admin in core apply to Supabase connections.
-- authenticated -> app_user (RLS-subject); service_role -> app_admin (BYPASSRLS).
GRANT app_user  TO authenticated;
GRANT app_admin TO service_role;
