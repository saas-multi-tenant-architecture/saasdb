-- new_user_trigger_uuid.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_meta_auth_users'
             AND conrelid = 'core.users_meta'::regclass) THEN
    ALTER TABLE core.users_meta DROP CONSTRAINT fk_users_meta_auth_users;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = core AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id::UUID, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user') THEN
    DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
    CREATE TRIGGER trg_on_better_auth_user_created
    AFTER INSERT ON "user"
    FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();
  END IF;
END $$;
