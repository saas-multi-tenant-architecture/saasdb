-- 00b_plain_pg_shim.sql
-- Purpose: Provide, on vanilla Postgres, the environment pieces the pgTap suite
-- assumed from Supabase: a Better-Auth-style "user" table and an auth-user setter
-- that uses app.current_user_id only (no GoTrue 'role').

CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT now(),
  "updatedAt" TIMESTAMPTZ DEFAULT now()
);

-- Override the helper so it does not reference Supabase roles.
CREATE OR REPLACE FUNCTION test_helpers.set_auth_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
END;
$$ LANGUAGE plpgsql;

-- create_test_user without auth.users / extensions.uuid_generate_v5.
CREATE OR REPLACE FUNCTION test_helpers.create_test_user(
  p_email TEXT, p_first_name TEXT DEFAULT NULL, p_last_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID := gen_random_uuid();
BEGIN
  INSERT INTO "user" (id, email, name) VALUES (v_user_id::text, p_email, p_first_name)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO core.users_meta (id, email, first_name, last_name)
  VALUES (v_user_id, p_email, p_first_name, p_last_name)
  ON CONFLICT (id) DO NOTHING;
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
