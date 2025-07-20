-- 002_platform_schema.sql
-- Purpose: Initial DDL for platform schema (SaaS-wide admin features)
-- This file is self-contained and should be run after utils schema

-- ========================================
-- SCHEMA CREATION
-- ========================================
CREATE SCHEMA IF NOT EXISTS platform;

-- ========================================
-- TABLES
-- ========================================


-- platform_roles: internal admin roles
CREATE TABLE platform.platform_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  priority INT NOT NULL,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- platform_users: internal admin users (linked to auth.users.id via FK)
CREATE TABLE platform.platform_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supabase_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- platform_organizations: control layer for tenant visibility
CREATE TABLE platform.platform_organizations (
  id UUID PRIMARY KEY,
  label TEXT NOT NULL,
  notes TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- platform_action_logs: tracks all admin activity
CREATE TABLE platform.platform_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_user_id UUID REFERENCES platform.platform_users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL, -- enum: select, create, update, delete, log, override 
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
);

-- platform_settings: global key-value config
CREATE TABLE platform.platform_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- platform_subscription_overrides: plan & feature overrides per org
CREATE TABLE platform.platform_subscription_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES platform.platform_organizations(id) ON DELETE CASCADE,
  plan_override TEXT,
  features JSONB,
  reason TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- platform_feature_flags: global or per-org feature toggles
CREATE TABLE platform.platform_feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL,
  organization_id UUID REFERENCES platform.platform_organizations(id) ON DELETE CASCADE,
  description TEXT,
  value JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- platform_system_events: infra-level activity or notices
CREATE TABLE platform.platform_system_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  summary TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- FOREIGN KEYS & INDEXES
-- ========================================
CREATE INDEX ON platform.platform_users (supabase_user_id);
CREATE INDEX ON platform.platform_action_logs (platform_user_id);
CREATE INDEX ON platform.platform_feature_flags (organization_id);
CREATE INDEX ON platform.platform_subscription_overrides (organization_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_users_updated
BEFORE UPDATE ON platform.platform_users
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

CREATE TRIGGER trg_platform_organizations_updated
BEFORE UPDATE ON platform.platform_organizations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

CREATE TRIGGER trg_platform_settings_updated
BEFORE UPDATE ON platform.platform_settings
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

CREATE TRIGGER trg_platform_subscription_overrides_updated
BEFORE UPDATE ON platform.platform_subscription_overrides
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

CREATE TRIGGER trg_platform_feature_flags_updated
BEFORE UPDATE ON platform.platform_feature_flags
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- RLS POLICIES (Optional)
-- ========================================
-- Consider applying `USING (false)` to all tables for defense in depth
-- Supabase access should be revoked at schema/table level

-- ========================================
-- NOTES
-- ========================================
-- All platform functions should be run by Supabase Edge Functions
-- using the service role only. These tables are not exposed to clients.
-- platform_users are linked to auth.users via supabase_user_id but not automatically created.
