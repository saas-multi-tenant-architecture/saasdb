-- tests/001_setup_auth.sql
-- Create a minimal auth schema and helper functions for testing

\set tenant_admin_id '00000000-0000-0000-0000-00000000A001'
\set tenant_user_id  '00000000-0000-0000-0000-00000000A002'
\set other_admin_id  '00000000-0000-0000-0000-00000000A003'
\set platform_admin_id '00000000-0000-0000-0000-00000000F001'

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL
);

-- Session-based user context
CREATE OR REPLACE FUNCTION auth.set_uid(p_uid uuid)
RETURNS void AS $$
BEGIN
  PERFORM set_config('app.current_user', p_uid::text, false);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT current_setting('app.current_user', true)::uuid;
$$;

INSERT INTO auth.users (id, email) VALUES
  (:'tenant_admin_id', 'admin@acme.com'),
  (:'tenant_user_id', 'user@acme.com'),
  (:'other_admin_id', 'beta@acme.com'),
  (:'platform_admin_id', 'platform@saas.com')
ON CONFLICT (id) DO NOTHING;
