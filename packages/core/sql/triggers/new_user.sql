-- new_user.sql
-- Purpose: Provide core.handle_new_user() — the function body that creates a users_meta row on new user signup.
-- Each adapter supplies the trigger that fires it (supabase: on auth.users; better-auth: on "user").

-- ========================================
-- FUNCTION: core.handle_new_user()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$;

-- ========================================
-- NOTES
-- ========================================
-- This ensures a users_meta row is automatically created for every new signup.
-- Includes the email field; other fields (names, avatar, etc.) can be updated later.
-- Must be run with elevated privileges.
-- The trigger that fires this function is supplied by each adapter:
--   supabase adapter : AFTER INSERT ON auth.users
--   better-auth adapter : AFTER INSERT ON "user"
