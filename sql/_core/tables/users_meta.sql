-- users_meta.sql
-- Purpose: Metadata table for users (1:1 with auth.users)

-- ========================================
-- TABLE: core.users_meta
-- ========================================
CREATE TABLE core.users_meta (
  id UUID PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_users_meta_updated
BEFORE UPDATE ON core.users_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- 1:1 relationship with auth.users (same UUID as primary key)
-- Intended for profile data that can be accessed within tenant context
