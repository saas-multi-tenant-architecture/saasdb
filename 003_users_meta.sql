-- 003_users_meta.sql
-- Purpose: Defines metadata table for users
-- This file assumes utils schema is already loaded for updated_at triggers

-- ========================================
-- TABLE CREATION
-- ========================================
CREATE TABLE app.users_meta (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_users_meta_updated
BEFORE UPDATE ON app.users_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- 1:1 relationship with auth.users (same UUID as primary key)
-- Intended for profile data that can be accessed within tenant context
-- No RLS policies applied yet; to be defined during RLS implementation
