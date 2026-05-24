-- roles.sql
-- Purpose: Role definitions with CASL-based permissions

-- ========================================
-- TABLE: core.roles
-- ========================================
CREATE TABLE core.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  casl_rules JSONB, -- JSONB column to store role CASL rules
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
CREATE TRIGGER trg_roles_updated
BEFORE UPDATE ON core.roles
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- CASL Rules Sample JSON Structure:
-- [
--   { "action": "read", "subject": "Ticket" },
--   { "action": ["update","close"], "subject": "Ticket" },
--   { "action": "delete", "subject": "Ticket", "inverted": true }
-- ]
-- ========================================
