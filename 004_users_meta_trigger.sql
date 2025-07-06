-- 004_users_meta_trigger.sql
-- Purpose: Automatically create a users_meta row after new user signup via Supabase auth
-- This file assumes app.users_meta is already defined (see 003_users_meta.sql)

-- ========================================
-- FUNCTION
-- ========================================
CREATE OR REPLACE FUNCTION app.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO app.users_meta (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- TRIGGER
-- ========================================
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION app.handle_new_user();

-- ========================================
-- NOTES
-- ========================================
-- This ensures a users_meta row is automatically created for every new signup
-- Includes the email field; other fields (names, avatar, etc.) can be updated later
-- Must be run with elevated privileges (service role)
-- This trigger is safe for all signup flows including OAuth
