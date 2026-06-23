-- auth_impl_mapped.sql
-- Better-Auth mapped mode: Better-Auth ids are arbitrary strings. SMTA mints its
-- own UUID per user and resolves external_id -> user_id on each call.
CREATE TABLE IF NOT EXISTS core.user_identities (
  external_id TEXT PRIMARY KEY,
  user_id     UUID NOT NULL UNIQUE DEFAULT gen_random_uuid()
);

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT user_id
  FROM core.user_identities
  WHERE external_id = NULLIF(current_setting('app.current_user_id', true), '');
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
