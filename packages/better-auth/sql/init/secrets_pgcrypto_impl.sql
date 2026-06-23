-- secrets_pgcrypto_impl.sql
-- Purpose: Non-Supabase secrets provider. Encrypts secret values with pgcrypto
-- (pgp_sym_encrypt) into core.encrypted_secrets, keyed by a generated UUID so the
-- reference is castable to UUID (stored in platform.tenant_secrets.vault_key_id).
-- The symmetric key is read from the GUC app.secrets_key, set by the backend per
-- session/connection. It is never hard-coded in SQL.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS core.encrypted_secrets (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT,
  ciphertext BYTEA NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
DECLARE
  v_key TEXT := NULLIF(current_setting('app.secrets_key', true), '');
  v_id  UUID;
BEGIN
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'app.secrets_key is not set; cannot encrypt secret';
  END IF;
  INSERT INTO core.encrypted_secrets (name, ciphertext)
  VALUES (p_name, pgp_sym_encrypt(p_secret, v_key))
  RETURNING id INTO v_id;
  RETURN v_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

CREATE OR REPLACE FUNCTION core.read_secret_impl(p_secret_ref TEXT)
RETURNS TEXT AS $$
DECLARE
  v_key TEXT := NULLIF(current_setting('app.secrets_key', true), '');
BEGIN
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'app.secrets_key is not set; cannot decrypt secret';
  END IF;
  RETURN (SELECT pgp_sym_decrypt(ciphertext, v_key) FROM core.encrypted_secrets WHERE id = p_secret_ref::UUID);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core;

CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
  DELETE FROM core.encrypted_secrets WHERE id = p_secret_ref::UUID;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = core;
