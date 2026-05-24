-- secrets_supabase_impl.sql
-- Purpose: Supabase Vault implementation of secrets provider.

CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
DECLARE
  v_vault_id UUID;
BEGIN
  SELECT vault.create_secret(p_secret, p_name) INTO v_vault_id;
  RETURN v_vault_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, vault, public;

CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
BEGIN
  DELETE FROM vault.secrets WHERE id = p_secret_ref::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, vault, public;
