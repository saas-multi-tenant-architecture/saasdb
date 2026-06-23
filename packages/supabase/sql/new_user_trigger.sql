-- new_user_trigger.sql
-- Purpose: Attach core.handle_new_user() to Supabase's auth.users table.
-- Core defines the function but is adapter-agnostic and does not bind it.
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION core.handle_new_user();
