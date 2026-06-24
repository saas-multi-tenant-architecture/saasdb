-- auth_interface.sql
-- Purpose: Declare core.get_current_user_id() stub.
-- Each adapter package overrides this. Calling it without an adapter raises an exception.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RAISE EXCEPTION 'core.get_current_user_id() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core;
