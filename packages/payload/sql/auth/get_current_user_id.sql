-- get_current_user_id.sql
-- Purpose: Payload CMS implementation — reads from session variable set by Node.js middleware.
-- Replaces the Supabase implementation (auth.uid()) when deploying with Payload.
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
