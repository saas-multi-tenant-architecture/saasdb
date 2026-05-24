-- secrets_interface.sql
-- Purpose: Declare secrets provider stubs for adapter override.

-- Called when storing a new secret. Returns an opaque reference ID.
CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
BEGIN
  RAISE EXCEPTION 'core.store_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

-- Called when deleting a secret by its reference ID.
CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
BEGIN
  RAISE EXCEPTION 'core.delete_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;
