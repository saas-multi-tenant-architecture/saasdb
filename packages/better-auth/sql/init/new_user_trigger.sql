-- new_user_trigger.sql
-- Purpose: Auto-create core.users_meta row when a user is created in better-auth.
-- Replaces the auth.users trigger used by @smta/supabase.
--
-- PREREQUISITE: Run better-auth's database migration before applying this file.
-- The trigger attaches only if the "user" table already exists, so deploying
-- this before better-auth's migration is a no-op (safe but incomplete).

-- ========================================
-- DROP SUPABASE FK CONSTRAINT (if present)
-- ========================================
-- @smta/supabase adds a FK from core.users_meta(id) → auth.users(id).
-- In a better-auth deployment, auth.users does not exist — drop the constraint
-- so the trigger can insert into core.users_meta without a Supabase dependency.
-- Safe to run even if the constraint does not exist (IF EXISTS guard).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fk_users_meta_auth_users'
      AND conrelid = 'core.users_meta'::regclass
  ) THEN
    ALTER TABLE core.users_meta DROP CONSTRAINT fk_users_meta_auth_users;
  END IF;
END $$;

-- ========================================
-- FUNCTION: core.handle_new_better_auth_user()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id::UUID, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER (conditional — only if user table exists)
-- ========================================
-- Attach trigger only when better-auth's user table is present.
-- If better-auth migration has not run, deploying this file is safe —
-- the function is created but the trigger is deferred.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'user'
  ) THEN
    DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
    CREATE TRIGGER trg_on_better_auth_user_created
    AFTER INSERT ON "user"
    FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();
  END IF;
END $$;
