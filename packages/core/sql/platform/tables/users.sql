-- users.sql
-- Purpose: Platform admin users table (user_id references the adapter's user identity).

-- ========================================
-- TABLE: platform.platform_users
-- ========================================
CREATE TABLE platform.platform_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role_id UUID NOT NULL REFERENCES platform.platform_roles(id),
  first_name TEXT,
  last_name TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX ON platform.platform_users (user_id);
CREATE INDEX ON platform.platform_users (role_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_users_updated
BEFORE UPDATE ON platform.platform_users
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();
