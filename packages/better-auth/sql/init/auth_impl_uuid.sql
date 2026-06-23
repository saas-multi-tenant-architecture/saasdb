-- auth_impl_uuid.sql
-- Better-Auth UUID mode: ids are already UUIDs (advanced.database.generateId).
-- get_current_user_id() reads the UUID straight from the session variable.
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
