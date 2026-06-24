-- roles.sql
-- Purpose: In a Better-Auth / plain-Postgres deployment there is no GoTrue role
-- trio. The application backend connects as a single login role that must inherit
-- app_user (RLS-subject). Migrations connect as a role inheriting app_admin.
-- This file is a documented hook: set smta.app_login_role / smta.admin_login_role
-- GUCs at deploy time to auto-wire membership, else wire it manually post-deploy.
DO $$
DECLARE
  v_app   TEXT := NULLIF(current_setting('smta.app_login_role',   true), '');
  v_admin TEXT := NULLIF(current_setting('smta.admin_login_role', true), '');
BEGIN
  IF v_app   IS NOT NULL THEN EXECUTE format('GRANT app_user  TO %I', v_app);   END IF;
  IF v_admin IS NOT NULL THEN EXECUTE format('GRANT app_admin TO %I', v_admin); END IF;
END $$;
