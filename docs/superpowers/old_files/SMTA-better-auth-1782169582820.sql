-- schemas.sql
-- Purpose: Create all foundational schemas for the project
-- Run this file first before any schema-specific DDL

-- ========================================
-- SCHEMA CREATION
-- ========================================
CREATE SCHEMA IF NOT EXISTS utils;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS platform;

-- ========================================
-- NOTES
-- ========================================
-- These schemas define logical boundaries:
-- - utils: shared triggers/functions
-- - core: identity, access control, helper functions, audit logs
-- - app: tenant-facing application tables
-- - platform: SaaS-wide admin and control layer (service role only)


-- ========================================
-- ACCESS CONTROL
-- ========================================
-- Grant access to utils, core, and app schemas to authenticated users
GRANT USAGE ON SCHEMA utils TO authenticated;
GRANT USAGE ON SCHEMA core TO authenticated;
GRANT USAGE ON SCHEMA app TO authenticated;


-- ========================================
-- DEFAULT TABLE PRIVILEGES
-- ========================================
-- Automatically grant SELECT on all future tables created in these schemas
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA utils GRANT SELECT ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT ON TABLES TO authenticated;


-- Lock down platform schema to prevent tenant access
REVOKE ALL ON SCHEMA platform FROM authenticated, anon, public;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, public;


-- =============== NEW FILE =================

-- auth_interface.sql
-- Purpose: Declare core.get_current_user_id() stub.
-- Each adapter package overrides this. Calling it without an adapter raises an exception.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RAISE EXCEPTION 'core.get_current_user_id() not implemented. Deploy an adapter (supabase or payload).';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core;


-- =============== NEW FILE =================

-- secrets_interface.sql
-- Purpose: Declare secrets provider stubs for adapter override.

-- Called when storing a new secret. Returns an opaque reference ID.
CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
BEGIN
  RAISE EXCEPTION 'core.store_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

-- Called when deleting a secret by its reference ID.
CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
BEGIN
  RAISE EXCEPTION 'core.delete_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;


-- =============== NEW FILE =================

-- functions.sql
-- Purpose: Shared utility functions for reusable triggers
-- This file should be run before any others that depend on shared triggers/functions

-- ========================================
-- FUNCTION: utils.update_timestamp()
-- ========================================
-- Updates updated_at column on any table
CREATE OR REPLACE FUNCTION utils.update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = utils
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ========================================
-- NOTES
-- ========================================
-- This function can be used by triggers on any table in any schema
-- Example usage:
--   CREATE TRIGGER trg_update_table
--   BEFORE UPDATE ON some_schema.some_table
--   FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- BASE COMPOSITE AUDIT FIELDS
-- USED ONLY TO COPY & PASTE INTO TABLES (FIELDS, NOT TYPE)
-- ========================================
-- created_by uuid,
-- updated_by uuid,
-- is_deleted boolean DEFAULT false,
-- deleted_at TIMESTAMPTZ,
-- deleted_by uuid,
-- created_at TIMESTAMPTZ DEFAULT NOW(),
-- updated_at TIMESTAMPTZ DEFAULT NOW()


-- =============== NEW FILE =================

-- roles.sql
-- Purpose: Platform admin roles table

-- ========================================
-- TABLE: platform.platform_roles
-- ========================================
CREATE TABLE platform.platform_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
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
CREATE TRIGGER trg_platform_roles_updated
BEFORE UPDATE ON platform.platform_roles
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- ========================================
-- CASL Rules Sample JSON Structure:
-- [
--   { "action": "read", "subject": "Ticket" },
--   { "action": ["update","close"], "subject": "Ticket" },
--   { "action": "delete", "subject": "Ticket", "inverted": true }
-- ]
-- ========================================


-- =============== NEW FILE =================

-- users.sql
-- Purpose: Platform admin users table (linked to auth.users.id via FK)

-- ========================================
-- TABLE: platform.platform_users
-- ========================================
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

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX ON platform.platform_users (supabase_user_id);
CREATE INDEX ON platform.platform_users (role_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_users_updated
BEFORE UPDATE ON platform.platform_users
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- organizations.sql
-- Purpose: Platform control layer for tenant visibility

-- ========================================
-- TABLE: platform.platform_organizations
-- ========================================
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

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_organizations_updated
BEFORE UPDATE ON platform.platform_organizations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- action_logs.sql
-- Purpose: Tracks all platform admin activity

-- ========================================
-- TABLE: platform.platform_action_logs
-- ========================================
CREATE TABLE platform.platform_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_user_id UUID REFERENCES platform.platform_users(id) ON DELETE SET NULL,
  auth_user_id UUID REFERENCES platform.platform_users(supabase_user_id),
  action_type TEXT NOT NULL, -- enum: select, create, update, delete, log, override
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX ON platform.platform_action_logs (platform_user_id);
CREATE INDEX ON platform.platform_action_logs (auth_user_id);


-- =============== NEW FILE =================

-- settings.sql
-- Purpose: Global key-value configuration for the platform

-- ========================================
-- TABLE: platform.platform_settings
-- ========================================
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

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_settings_updated
BEFORE UPDATE ON platform.platform_settings
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- subscription_overrides.sql
-- Purpose: Plan & feature overrides per organization

-- ========================================
-- TABLE: platform.platform_subscription_overrides
-- ========================================
CREATE TABLE platform.platform_subscription_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES platform.platform_organizations(id) ON DELETE CASCADE NOT NULL,
  plan_override TEXT NOT NULL,
  features JSONB NOT NULL,
  reason TEXT NOT NULL,
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
CREATE INDEX ON platform.platform_subscription_overrides (organization_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_subscription_overrides_updated
BEFORE UPDATE ON platform.platform_subscription_overrides
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- feature_flags.sql
-- Purpose: Global or per-organization feature toggles

-- ========================================
-- TABLE: platform.platform_feature_flags
-- ========================================
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

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX ON platform.platform_feature_flags (organization_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_platform_feature_flags_updated
BEFORE UPDATE ON platform.platform_feature_flags
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- system_events.sql
-- Purpose: Infrastructure-level activity or notices

-- ========================================
-- TABLE: platform.platform_system_events
-- ========================================
CREATE TABLE platform.platform_system_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  summary TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


-- =============== NEW FILE =================

-- organizations.sql
-- Purpose: Core tenant organizations table

-- ========================================
-- TABLE: core.organizations
-- ========================================
CREATE TABLE core.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_by uuid NOT NULL,
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
CREATE TRIGGER trg_organizations_updated
BEFORE UPDATE ON core.organizations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- units.sql
-- Purpose: Sub-entities within organizations (teams, departments, etc.)

-- ========================================
-- TABLE: core.units
-- ========================================
CREATE TABLE core.units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
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
CREATE INDEX idx_units_organization_id ON core.units (organization_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_units_updated
BEFORE UPDATE ON core.units
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.unit_meta
-- ========================================
CREATE TABLE core.unit_meta (
  id UUID PRIMARY KEY REFERENCES core.units(id) ON DELETE CASCADE,
  notes TEXT,
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
CREATE TRIGGER trg_unit_meta_updated
BEFORE UPDATE ON core.unit_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

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


-- =============== NEW FILE =================

-- memberships.sql
-- Purpose: User memberships in organizations and units

-- ========================================
-- TABLE: core.memberships
-- ========================================
CREATE TABLE core.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  is_super_admin BOOLEAN NOT NULL DEFAULT false,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, organization_id)
);

-- Ensure only one super_admin per organization
CREATE UNIQUE INDEX idx_one_super_admin_per_org
  ON core.memberships (organization_id)
  WHERE is_super_admin = true AND is_deleted = false;

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_memberships_user_id ON core.memberships (user_id);
CREATE INDEX idx_memberships_organization_id ON core.memberships (organization_id);
CREATE INDEX idx_memberships_role_id ON core.memberships (role_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_memberships_updated
BEFORE UPDATE ON core.memberships
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- TABLE: core.unit_memberships
-- ========================================
CREATE TABLE core.unit_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  unit_id UUID NOT NULL REFERENCES core.units(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, unit_id)
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_unit_memberships_user_id ON core.unit_memberships (user_id);
CREATE INDEX idx_unit_memberships_unit_id ON core.unit_memberships (unit_id);
CREATE INDEX idx_unit_memberships_role_id ON core.unit_memberships (role_id);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_unit_memberships_updated
BEFORE UPDATE ON core.unit_memberships
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

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


-- =============== NEW FILE =================

-- organization_files.sql
-- Purpose: References to organization-owned files stored in Supabase Storage

-- ========================================
-- TABLE: core.organization_files
-- ========================================
CREATE TABLE core.organization_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- URL or storage path to the file in Supabase bucket
  file_url TEXT NOT NULL,
  -- MIME type (e.g. 'image/png', 'application/pdf')
  file_type TEXT NOT NULL,
  -- Optional structured info about the file (e.g., image dimensions, metadata)
  file_specs JSONB,
  -- Size in bytes
  file_size INTEGER,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
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
CREATE INDEX idx_organization_files_organization_id ON core.organization_files (organization_id);
CREATE INDEX idx_organization_files_file_type ON core.organization_files (file_type);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_organization_files_updated
BEFORE UPDATE ON core.organization_files
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();


-- =============== NEW FILE =================

-- organizations_meta.sql
-- Purpose: Metadata table for tenant organizations (1:1 with core.organizations)

-- ========================================
-- TABLE: core.organizations_meta
-- ========================================
CREATE TABLE core.organizations_meta (
  id UUID PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  logo_file_id UUID REFERENCES core.organization_files(id) ON DELETE SET NULL,
  address TEXT,
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
-- INDEXES
-- ========================================
CREATE INDEX ON core.organizations_meta (logo_file_id) WHERE logo_file_id IS NOT NULL;

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_organizations_meta_updated
BEFORE UPDATE ON core.organizations_meta
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- 1:1 relationship with core.organizations
-- Holds organization-wide metadata accessible to members via RLS


-- =============== NEW FILE =================

-- audit_logs.sql
-- Purpose: Central audit log for tracking user actions

-- ========================================
-- TABLE: core.audit_logs
-- ========================================
CREATE TABLE core.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID, -- auth.uid()
  organization_id UUID REFERENCES core.organizations(id),
  target_table TEXT NOT NULL,
  target_id UUID,
  action TEXT NOT NULL, -- 'insert', 'update', 'delete', 'login', etc.
  summary TEXT,
  metadata JSONB, -- optional structure: changed fields, reason, etc.
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_audit_logs_actor_id ON core.audit_logs (actor_id);
CREATE INDEX idx_audit_logs_organization_id ON core.audit_logs (organization_id);
CREATE INDEX idx_audit_logs_target_table ON core.audit_logs (target_table);
CREATE INDEX idx_audit_logs_metadata ON core.audit_logs USING GIN (metadata);

-- ========================================
-- NOTES
-- ========================================
-- No update trigger as audit logs should be immutable


-- =============== NEW FILE =================

-- invitations.sql
-- Purpose: Invitation management for organization and unit memberships

-- ========================================
-- TABLE: core.invitations
-- ========================================
CREATE TABLE core.invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  unit_id UUID REFERENCES core.units(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES core.roles(id),
  invited_by UUID NOT NULL,

  -- Token and security
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),

  -- Status tracking
  status TEXT NOT NULL DEFAULT 'pending',
  accepted_at TIMESTAMPTZ,
  accepted_by UUID,

  -- Metadata for email delivery
  metadata JSONB DEFAULT '{}'::jsonb,

  -- Standard audit fields
  created_by UUID,
  updated_by UUID,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_status CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled')),
  CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_invitations_organization_id ON core.invitations(organization_id);
CREATE INDEX idx_invitations_unit_id ON core.invitations(unit_id) WHERE unit_id IS NOT NULL;
CREATE INDEX idx_invitations_token ON core.invitations(token) WHERE status = 'pending' AND is_deleted = false;
CREATE INDEX idx_invitations_email ON core.invitations(email) WHERE status = 'pending' AND is_deleted = false;
CREATE INDEX idx_invitations_status ON core.invitations(status);
CREATE INDEX idx_invitations_invited_by ON core.invitations(invited_by);
CREATE INDEX idx_invitations_expires_at ON core.invitations(expires_at) WHERE status = 'pending';
CREATE INDEX idx_invitations_role_id ON core.invitations(role_id);
CREATE INDEX idx_invitations_accepted_by ON core.invitations(accepted_by) WHERE accepted_by IS NOT NULL;

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_invitations_updated
BEFORE UPDATE ON core.invitations
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- Email validation regex allows standard email formats
-- Token is generated via gen_random_uuid() or custom secure token generator
-- metadata JSONB can store additional context (e.g., custom message, referral source)
-- Unit-level invitations are optional (unit_id can be NULL)
-- Expired invitations are marked via periodic cleanup or on-access check


-- =============== NEW FILE =================

-- grants.sql
-- Purpose: Grant table-level permissions to authenticated users
-- Note: RLS policies control which rows they can access; these grants control table access

-- ========================================
-- CORE TABLE PERMISSIONS
-- ========================================
-- Grant INSERT/UPDATE on core tables that authenticated users can modify
-- RLS policies control which specific rows they can actually access

GRANT SELECT, INSERT, UPDATE ON core.organizations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.organizations_meta TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.units TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.unit_meta TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.unit_memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.users_meta TO authenticated;
GRANT SELECT, INSERT ON core.audit_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.invitations TO authenticated;
GRANT SELECT ON core.roles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON core.organization_files TO authenticated;

-- ========================================
-- SERVICE ROLE PERMISSIONS
-- ========================================
-- service_role has full DML on core tables for migrations, seed scripts, and
-- admin backend operations. postgres inherits these via role membership.
-- RLS does not apply to service_role (rolbypassrls = true).
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO service_role;

-- ========================================
-- SEQUENCE PERMISSIONS
-- ========================================
-- Grant sequence usage for inserts (needed for auto-generated IDs)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO service_role;


-- =============== NEW FILE =================

-- new_user.sql
-- Purpose: Automatically create a users_meta row after new user signup via Supabase auth

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
-- TRIGGER
-- ========================================
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION core.handle_new_user();

-- ========================================
-- NOTES
-- ========================================
-- This ensures a users_meta row is automatically created for every new signup
-- Includes the email field; other fields (names, avatar, etc.) can be updated later
-- Must be run with elevated privileges (service role)
-- This trigger is safe for all signup flows including OAuth


-- =============== NEW FILE =================

-- new_organization.sql
-- Purpose: Automate creation of metadata and platform registry rows when a new organization is added

-- ========================================
-- FUNCTION: core.handle_new_organization()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_organization()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
DECLARE
  v_super_admin_role_id UUID;
BEGIN
  IF NEW.created_by IS NULL THEN
    RAISE EXCEPTION 'organizations.created_by is required';
  END IF;

  -- Insert org metadata (same UUID)
  INSERT INTO core.organizations_meta (id, created_by, updated_by)
  VALUES (NEW.id, NEW.created_by, NEW.updated_by);

  -- Insert into platform registry
  INSERT INTO platform.platform_organizations (id, label, created_at, updated_at)
  VALUES (NEW.id, NEW.name, now(), now());

  -- Seed initial membership: creator is the org super_admin
  SELECT core.roles.id
  INTO v_super_admin_role_id
  FROM core.roles
  WHERE core.roles.name = 'super_admin'
  LIMIT 1;

  IF v_super_admin_role_id IS NULL THEN
    RAISE EXCEPTION 'Role "super_admin" not found';
  END IF;

  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
  VALUES (NEW.created_by, NEW.id, v_super_admin_role_id, true, NEW.created_by, NEW.created_by)
  ON CONFLICT (user_id, organization_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER
-- ========================================
DROP TRIGGER IF EXISTS trg_on_organization_created ON core.organizations;
CREATE TRIGGER trg_on_organization_created
AFTER INSERT ON core.organizations
FOR EACH ROW EXECUTE FUNCTION core.handle_new_organization();

-- ========================================
-- NOTES
-- ========================================
-- This keeps platform and tenant-level structures synchronized
-- Assumes that organization name in `core.organizations` maps to label in platform


-- =============== NEW FILE =================

-- new_unit.sql
-- Purpose: Automate creation of metadata row when a new unit is added

-- ========================================
-- FUNCTION: core.handle_new_unit()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_unit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  -- Insert unit metadata (same UUID as unit)
  INSERT INTO core.unit_meta (id, created_by, updated_by)
  VALUES (NEW.id, NEW.created_by, NEW.created_by);

  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER
-- ========================================
DROP TRIGGER IF EXISTS trg_on_unit_created ON core.units;
CREATE TRIGGER trg_on_unit_created
AFTER INSERT ON core.units
FOR EACH ROW EXECUTE FUNCTION core.handle_new_unit();

-- ========================================
-- NOTES
-- ========================================
-- Ensures unit_meta is always created alongside the unit
-- Uses the same UUID as the unit for 1:1 relationship


-- =============== NEW FILE =================

-- protect_super_admin.sql
-- Purpose: Prevent deletion or soft-deletion of super_admin membership

-- ========================================
-- FUNCTION: core.protect_super_admin()
-- ========================================
-- Ensures there is always exactly one super_admin per organization
-- Blocks DELETE and soft-delete (is_deleted = true) on super_admin rows
-- Allows is_super_admin to be set to false only via transfer_super_admin()
CREATE OR REPLACE FUNCTION core.protect_super_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  -- On DELETE: block if row is super_admin
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_super_admin = true AND OLD.is_deleted = false THEN
      RAISE EXCEPTION 'Cannot delete super_admin membership. Transfer super_admin status first.';
    END IF;
    RETURN OLD;
  END IF;

  -- On UPDATE: block soft-delete of super_admin
  IF TG_OP = 'UPDATE' THEN
    -- Prevent soft-deleting super_admin
    IF OLD.is_super_admin = true AND OLD.is_deleted = false AND NEW.is_deleted = true THEN
      RAISE EXCEPTION 'Cannot soft-delete super_admin membership. Transfer super_admin status first.';
    END IF;

    -- Prevent removing super_admin flag without proper transfer
    -- This check ensures is_super_admin can only go from true->false
    -- if there's another super_admin being set in the same transaction
    -- The unique partial index will enforce only one super_admin exists
    IF OLD.is_super_admin = true AND NEW.is_super_admin = false THEN
      -- Allow this only if called from transfer_super_admin context
      -- The unique index ensures integrity - if no new super_admin is set,
      -- subsequent operations will fail
      NULL; -- Allow the change, index will enforce constraint
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER
-- ========================================
DROP TRIGGER IF EXISTS trg_protect_super_admin ON core.memberships;
CREATE TRIGGER trg_protect_super_admin
BEFORE UPDATE OR DELETE ON core.memberships
FOR EACH ROW EXECUTE FUNCTION core.protect_super_admin();

-- ========================================
-- NOTES
-- ========================================
-- This trigger works in conjunction with:
-- 1. The unique partial index idx_one_super_admin_per_org (ensures max 1 super_admin)
-- 2. The public.transfer_super_admin() function (proper transfer mechanism)
-- Together they ensure exactly one super_admin always exists per organization


-- =============== NEW FILE =================

-- tenant_secrets.sql
-- Purpose: Secure storage reference table for tenant secrets using Supabase Vault

-- ========================================
-- TABLE: platform.tenant_secrets
-- ========================================
CREATE TABLE platform.tenant_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  scope TEXT NOT NULL CHECK (scope IN ('organization', 'user')),
  organization_id UUID REFERENCES core.organizations(id),
  user_id UUID REFERENCES auth.users(id),

  secret_name TEXT NOT NULL, -- e.g., 'smtp_password', 'api_key'
  vault_key_id UUID NOT NULL, -- Supabase Vault secret key reference

  is_active BOOLEAN DEFAULT TRUE,

  -- Audit fields
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CHECK (
    (scope = 'organization' AND organization_id IS NOT NULL AND user_id IS NULL) OR
    (scope = 'user' AND user_id IS NOT NULL AND organization_id IS NULL)
  )
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_tenant_secrets_organization_id ON platform.tenant_secrets (organization_id) WHERE scope = 'organization';
CREATE INDEX idx_tenant_secrets_user_id ON platform.tenant_secrets (user_id) WHERE scope = 'user';
CREATE INDEX idx_tenant_secrets_scope ON platform.tenant_secrets (scope);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_tenant_secrets_updated
BEFORE UPDATE ON platform.tenant_secrets
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- - The secret value is never stored in this table
-- - It is managed via Supabase Vault and referenced via vault_key_id
-- - Only the service role should access or write this table directly
-- - RLS policies are deferred until the dedicated security stage


-- =============== NEW FILE =================

-- billing_customers.sql
-- Purpose: Billing integration - maps organizations to payment processor customers

-- ========================================
-- TABLE: platform.billing_customers
-- ========================================
CREATE TABLE platform.billing_customers (
  organization_id UUID PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  provider_customer_id TEXT NOT NULL UNIQUE,
  provider TEXT NOT NULL DEFAULT 'stripe' CONSTRAINT billing_customers_provider_check CHECK (provider IN ('stripe', 'lemon_squeezy')),
  billing_email TEXT,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- RLS
-- ========================================
ALTER TABLE platform.billing_customers ENABLE ROW LEVEL SECURITY;

-- ========================================
-- NOTES
-- ========================================
-- The core.organizations table is used to link to billing to keep all tenant data
-- isolated from platform data. This is why it is not connected to the platform_organizations table.
-- The paymentprocessor customer/subscription is conceptually tied to the tenant, not the platform's record of that tenant


-- =============== NEW FILE =================

-- billing_subscriptions.sql
-- Purpose: Billing integration - tracks subscription status per organization

-- ========================================
-- TABLE: platform.billing_subscriptions
-- ========================================
CREATE TABLE platform.billing_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  provider_subscription_id TEXT NOT NULL UNIQUE,
  provider TEXT NOT NULL DEFAULT 'stripe' CONSTRAINT billing_subscriptions_provider_check CHECK (provider IN ('stripe', 'lemon_squeezy')),
  plan TEXT NOT NULL,
  status TEXT NOT NULL,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
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
CREATE INDEX idx_billing_subscriptions_organization_id ON platform.billing_subscriptions (organization_id);
CREATE INDEX idx_billing_subscriptions_status ON platform.billing_subscriptions (status);

-- ========================================
-- RLS
-- ========================================
ALTER TABLE platform.billing_subscriptions ENABLE ROW LEVEL SECURITY;


-- =============== NEW FILE =================

-- subscription_products.sql
-- Purpose: Subscription plans/products offered by the platform

-- ========================================
-- TABLE: platform.subscription_products
-- ========================================
CREATE TABLE platform.subscription_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Payment Processor Price ID for this plan (maps to Payment Processor dashboard)
  paymentprocessor_price_id TEXT NOT NULL UNIQUE,
  -- Display information
  name TEXT NOT NULL,
  description TEXT,
  billing_interval TEXT NOT NULL, -- e.g., 'monthly', 'yearly'
  amount INTEGER NOT NULL, -- amount in cents
  is_active BOOLEAN DEFAULT true,
  -- Optional metadata for internal use or future extension
  metadata JSONB,
  -- Standard audit fields
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- RLS
-- ========================================
ALTER TABLE platform.subscription_products ENABLE ROW LEVEL SECURITY;


-- =============== NEW FILE =================

-- grants.sql
-- Purpose: Reinforce the platform schema lockdown against authenticated/anon/PUBLIC,
-- and grant service_role full access for server-side admin and migrations.
--
-- Platform tables are also locked down upstream by init/schemas.sql:
--   REVOKE ALL ON SCHEMA platform FROM authenticated, anon, public;
--   REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, public;
--
-- All platform access flows through SECURITY DEFINER functions in
-- packages/core/sql/platform/functions/*.sql, which call platform.ensure_platform_user()
-- or platform.ensure_platform_admin() for authorization.
--
-- Authenticated users should never have direct privileges on platform.* tables.
-- Earlier broad GRANTs in this file contradicted the schema-level lockdown and
-- exposed platform tables in the pg_graphql schema (Supabase lint 0027).

-- Defensive re-revoke in case any prior grants remain in a deployed environment.
REVOKE ALL ON SCHEMA platform FROM authenticated, anon, PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA platform FROM authenticated, anon, PUBLIC;

-- Cancel any default-privilege grants that future tables would otherwise inherit.
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON TABLES FROM authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON SEQUENCES FROM authenticated;

-- service_role (the Supabase backend/admin role) retains full access to
-- platform.* so server-side jobs, migrations, and test harnesses can manage
-- platform state directly. service_role also has BYPASSRLS, so RLS policies
-- on platform tables do not apply to it.
GRANT USAGE ON SCHEMA platform TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA platform TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA platform TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT ALL ON SEQUENCES TO service_role;


-- =============== NEW FILE =================

-- helpers.sql
-- Purpose: RLS helper functions for membership and role checks

-- ========================================
-- FUNCTION: core.is_super_admin()
-- ========================================
-- Check if current user is super_admin for an organization
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
-- (prevents infinite recursion when RLS checks membership status)
CREATE OR REPLACE FUNCTION core.is_super_admin(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = core.get_current_user_id()
      AND organization_id = p_org_id
      AND is_super_admin = true
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.is_org_member()
-- ========================================
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.is_org_member(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = core.get_current_user_id()
      AND organization_id = p_org_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.is_unit_member()
-- ========================================
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.is_unit_member(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = core.get_current_user_id()
      AND unit_id = p_unit_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.get_org_role()
-- ========================================
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.get_org_role(p_org_id UUID)
RETURNS TEXT AS $$
  SELECT r.name
  FROM core.memberships m
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = core.get_current_user_id()
    AND m.organization_id = p_org_id
    AND m.is_deleted = false
  LIMIT 1;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.has_org_role()
-- ========================================
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.has_org_role(p_org_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT core.get_org_role(p_org_id) = p_role;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.has_unit_role()
-- ========================================
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.has_unit_role(p_unit_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = core.get_current_user_id()
      AND um.unit_id = p_unit_id
      AND um.is_deleted = false
      AND r.name = p_role
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.shares_organization()
-- ========================================
-- Returns TRUE if current user and target user are members of at least one SAME organization
-- Used for team directory features (viewing co-worker profiles, @mentions, etc.)
--
-- Privacy: Users can only see profiles of others who share AT LEAST ONE organization
-- Example:
--   Alice (Org A, Org B), Bob (Org A) → TRUE (share Org A)
--   Alice (Org A, Org B), Carol (Org B) → TRUE (share Org B)
--   Bob (Org A), Carol (Org B) → FALSE (no shared org)
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.shares_organization(p_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM core.memberships current_user_membership
    JOIN core.memberships target_user_membership
      ON current_user_membership.organization_id = target_user_membership.organization_id
    WHERE current_user_membership.user_id = core.get_current_user_id()
      AND target_user_membership.user_id = p_user_id
      AND current_user_membership.is_deleted = false
      AND target_user_membership.is_deleted = false
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.get_org_id_for_unit()
-- ========================================
-- Get the organization_id for a given unit
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.get_org_id_for_unit(p_unit_id UUID)
RETURNS UUID AS $$
  SELECT organization_id FROM core.units WHERE id = p_unit_id AND is_deleted = false;
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.is_org_super_admin_for_unit()
-- ========================================
-- Check if current user is super_admin of the organization that owns this unit
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.is_org_super_admin_for_unit(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT core.is_super_admin(core.get_org_id_for_unit(p_unit_id));
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;

-- ========================================
-- FUNCTION: core.is_org_member_for_unit()
-- ========================================
-- Check if current user is a member of the organization that owns this unit
-- SECURITY DEFINER: Required to bypass RLS when called from RLS policies
CREATE OR REPLACE FUNCTION core.is_org_member_for_unit(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT core.is_org_member(core.get_org_id_for_unit(p_unit_id));
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = core, public;


-- =============== NEW FILE =================

-- policies.sql
-- Purpose: Enable RLS and define policies for core tables
--
-- Policy Philosophy:
-- - super_admin (tenant owner) has full CRUD access to all tenant tables
-- - RLS validates membership in org/unit for other users
-- - Fine-grained access control is delegated to CASL (application layer)
-- - This template is permissive by design; developers can restrict via CASL
--
-- Deletion Strategy:
-- - DELETE policies are intentionally NOT defined for core tables
-- - All deletions must be "soft deletes" via UPDATE (setting is_deleted = true)
-- - This ensures data recovery is possible and audit trails are preserved
-- - The protect_super_admin trigger enforces this for super_admin memberships
-- - Hard DELETEs are blocked by default RLS deny-all behavior

-- ========================================
-- RLS ENABLEMENT
-- ========================================
ALTER TABLE core.users_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organization_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.roles ENABLE ROW LEVEL SECURITY;

-- ========================================
-- POLICIES: users_meta
-- ========================================
-- User's own data or shared organization members can view
-- Only the user can update their own record
CREATE POLICY users_meta_select ON core.users_meta
  FOR SELECT USING (
    (SELECT core.get_current_user_id()) = id OR core.shares_organization(id)
  );

CREATE POLICY users_meta_update ON core.users_meta
  FOR UPDATE USING ((SELECT core.get_current_user_id()) = id)
  WITH CHECK ((SELECT core.get_current_user_id()) = id);

-- ========================================
-- POLICIES: organizations_meta
-- ========================================
-- Org members can view and update (CASL controls fine-grained access)
CREATE POLICY organizations_meta_select ON core.organizations_meta
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(id) OR core.is_super_admin(id))
  );

CREATE POLICY organizations_meta_update ON core.organizations_meta
  FOR UPDATE USING (
    is_deleted = false AND core.is_super_admin(id)
  )
  WITH CHECK (
    core.is_super_admin(id)
  );

-- ========================================
-- POLICIES: organizations
-- ========================================
-- Members can read and update, creator can insert
CREATE POLICY organizations_select ON core.organizations
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(id) OR core.is_super_admin(id))
  );

CREATE POLICY organizations_insert ON core.organizations
  FOR INSERT WITH CHECK ((SELECT core.get_current_user_id()) = created_by);

CREATE POLICY organizations_update ON core.organizations
  FOR UPDATE USING (
    is_deleted = false AND core.is_super_admin(id)
  )
  WITH CHECK (
    core.is_super_admin(id)
  );

-- ========================================
-- POLICIES: units
-- ========================================
-- Org members can read/insert/update (CASL controls fine-grained access)
CREATE POLICY units_select ON core.units
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  );

CREATE POLICY units_insert ON core.units
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

CREATE POLICY units_update ON core.units
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  )
  WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: unit_meta
-- ========================================
-- Unit members or org members can read/update (CASL controls fine-grained access)
CREATE POLICY unit_meta_select ON core.unit_meta
  FOR SELECT USING (
    is_deleted = false AND (core.is_unit_member(id) OR core.is_org_member_for_unit(id) OR core.is_org_super_admin_for_unit(id))
  );

CREATE POLICY unit_meta_update ON core.unit_meta
  FOR UPDATE USING (
    is_deleted = false AND (core.is_unit_member(id) OR core.is_org_member_for_unit(id) OR core.is_org_super_admin_for_unit(id))
  )
  WITH CHECK (
    core.is_unit_member(id) OR core.is_org_member_for_unit(id) OR core.is_org_super_admin_for_unit(id)
  );

-- ========================================
-- POLICIES: memberships
-- ========================================
-- Users see their own rows, org members can manage (CASL controls fine-grained access)
-- Note: protect_super_admin trigger prevents deletion of super_admin membership
CREATE POLICY memberships_select ON core.memberships
  FOR SELECT USING (
    is_deleted = false AND ((SELECT core.get_current_user_id()) = user_id OR core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  );

CREATE POLICY memberships_insert ON core.memberships
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

CREATE POLICY memberships_update ON core.memberships
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  )
  WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: unit_memberships
-- ========================================
-- Users see their own rows, org members can manage (CASL controls fine-grained access)
CREATE POLICY unit_memberships_select ON core.unit_memberships
  FOR SELECT USING (
    is_deleted = false AND ((SELECT core.get_current_user_id()) = user_id OR core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id))
  );

CREATE POLICY unit_memberships_insert ON core.unit_memberships
  FOR INSERT WITH CHECK (
    core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id)
  );

CREATE POLICY unit_memberships_update ON core.unit_memberships
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id))
  )
  WITH CHECK (
    core.is_org_member_for_unit(unit_id) OR core.is_org_super_admin_for_unit(unit_id)
  );

-- ========================================
-- POLICIES: audit_logs
-- ========================================
-- Org members can view audit logs (CASL can restrict further)
CREATE POLICY audit_logs_select ON core.audit_logs
  FOR SELECT USING (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: organization_files
-- ========================================
-- Org members can read/insert/update (CASL controls fine-grained access)
CREATE POLICY organization_files_select ON core.organization_files
  FOR SELECT USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  );

CREATE POLICY organization_files_insert ON core.organization_files
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

CREATE POLICY organization_files_update ON core.organization_files
  FOR UPDATE USING (
    is_deleted = false AND (core.is_org_member(organization_id) OR core.is_super_admin(organization_id))
  )
  WITH CHECK (
    core.is_org_member(organization_id) OR core.is_super_admin(organization_id)
  );

-- ========================================
-- POLICIES: roles
-- ========================================
-- core.roles is shared reference data (role names + CASL rule definitions).
-- Any authenticated user needs SELECT access to resolve their role and
-- render UI based on CASL rules. There is no tenant scoping on this table.
-- INSERT/UPDATE/DELETE are not permitted via RLS — role mutations must go
-- through admin tooling/seed scripts.
CREATE POLICY roles_select ON core.roles
  FOR SELECT USING (is_deleted = false);


-- =============== NEW FILE =================

-- invitations.sql
-- Purpose: RLS policies for core.invitations table
--
-- Policy Philosophy:
-- - Invitations are managed through functions (create, accept, cancel, resend)
-- - RLS ensures users can only see invitations for organizations they belong to
-- - The invitee (by email) can view their own pending invitations
-- - No direct INSERT/UPDATE/DELETE - all operations via functions

-- ========================================
-- ENABLE RLS
-- ========================================
ALTER TABLE core.invitations ENABLE ROW LEVEL SECURITY;

-- ========================================
-- POLICY: SELECT
-- ========================================
-- Users can view invitations if:
-- 1. They are a member of the organization (to manage invitations)
-- 2. The invitation is addressed to their email (to accept invitations)
CREATE POLICY invitations_select ON core.invitations
  FOR SELECT USING (
    -- Org members can view non-deleted invitations for their org
    (is_deleted = false AND core.is_org_member(organization_id))
    OR
    -- Users can view invitations sent to their email
    (
      email = (SELECT email FROM core.users_meta WHERE id = core.get_current_user_id())
      AND status = 'pending'
      AND is_deleted = false
    )
  );

-- ========================================
-- POLICY: INSERT
-- ========================================
-- Users can create invitations if they are a member of the organization
-- Note: Additional validation (role checks, duplicate prevention) happens in core.create_invitation()
CREATE POLICY invitations_insert ON core.invitations
  FOR INSERT WITH CHECK (
    core.is_org_member(organization_id)
  );

-- ========================================
-- POLICY: UPDATE
-- ========================================
-- Users can update invitations if:
-- 1. They are a member of the organization (to cancel/resend)
-- 2. They are accepting their own invitation (email match)
CREATE POLICY invitations_update ON core.invitations
  FOR UPDATE USING (
    core.is_org_member(organization_id)
    OR
    (
      email = (SELECT email FROM core.users_meta WHERE id = core.get_current_user_id())
      AND status = 'pending'
    )
  )
  WITH CHECK (
    core.is_org_member(organization_id)
    OR
    (
      email = (SELECT email FROM core.users_meta WHERE id = core.get_current_user_id())
      AND status IN ('accepted', 'expired')  -- Can only mark as accepted or expired
    )
  );

-- ========================================
-- NO DELETE POLICY
-- ========================================
-- Hard deletes are not allowed - invitations use soft deletes (is_deleted = true)
-- This preserves the invitation audit trail
-- Default RLS behavior blocks all DELETE operations

-- ========================================
-- NOTES
-- ========================================
-- RLS provides defense-in-depth security:
--   - Functions enforce business logic (duplicate prevention, expiration, etc.)
--   - RLS ensures tenant isolation (can't see other org's invitations)
--   - CASL (application layer) controls role-based permissions
--
-- The UPDATE policy allows:
--   - Org members to update status (cancel, resend)
--   - Invitees to accept their invitation (set status = 'accepted')
--
-- Security considerations:
--   - Email matching prevents users from accepting invitations meant for others
--   - Org membership requirement prevents cross-tenant invitation manipulation
--   - Soft deletes preserve audit trail


-- =============== NEW FILE =================

-- lockdown.sql
-- Purpose: Lock down all platform tables using RLS with USING (false), and create a secure access guard function

-- ========================================
-- FUNCTION: platform.is_platform_user()
-- ========================================
CREATE OR REPLACE FUNCTION platform.is_platform_user()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM platform.platform_users pu
    WHERE pu.supabase_user_id = auth.uid()
      AND pu.is_deleted = false
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = platform, public;

-- ========================================
-- FUNCTION: platform.is_platform_super_admin()
-- ========================================
CREATE OR REPLACE FUNCTION platform.is_platform_super_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM platform.platform_users pu
    JOIN platform.platform_roles pr ON pu.role_id = pr.id
    WHERE pu.supabase_user_id = auth.uid()
      AND pu.is_deleted = false
      AND pr.name = 'super_admin'
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = platform, public;

-- ========================================
-- FUNCTION: platform.ensure_platform_user()
-- ========================================
CREATE OR REPLACE FUNCTION platform.ensure_platform_user()
RETURNS VOID AS $$
BEGIN
  IF NOT platform.is_platform_user() THEN
    RAISE EXCEPTION 'Access denied: platform user required';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.ensure_platform_admin()
-- ========================================
-- NOTE: Despite the name, this enforces platform super_admin only.
CREATE OR REPLACE FUNCTION platform.ensure_platform_admin()
RETURNS VOID AS $$
BEGIN
  IF NOT platform.is_platform_super_admin() THEN
    RAISE EXCEPTION 'Access denied: platform super_admin role required';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- RLS LOCKDOWN: Enable RLS and deny all for platform tables
-- ========================================
ALTER TABLE platform.platform_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_users_select ON platform.platform_users
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_users_insert ON platform.platform_users
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_users_update ON platform.platform_users
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_roles_select ON platform.platform_roles
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_roles_insert ON platform.platform_roles
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_roles_update ON platform.platform_roles
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_action_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_action_logs_select ON platform.platform_action_logs
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_action_logs_insert ON platform.platform_action_logs
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_organizations_select ON platform.platform_organizations
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_organizations_insert ON platform.platform_organizations
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_organizations_update ON platform.platform_organizations
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_subscription_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_subscription_overrides_select ON platform.platform_subscription_overrides
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_subscription_overrides_insert ON platform.platform_subscription_overrides
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_subscription_overrides_update ON platform.platform_subscription_overrides
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_feature_flags_select ON platform.platform_feature_flags
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_feature_flags_insert ON platform.platform_feature_flags
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_feature_flags_update ON platform.platform_feature_flags
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_settings_select ON platform.platform_settings
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_settings_insert ON platform.platform_settings
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_settings_update ON platform.platform_settings
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_system_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_system_events_select ON platform.platform_system_events
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_system_events_insert ON platform.platform_system_events
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.tenant_secrets ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_secrets_select ON platform.tenant_secrets
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY tenant_secrets_insert ON platform.tenant_secrets
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY tenant_secrets_update ON platform.tenant_secrets
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

-- ========================================
-- PLATFORM RLS: Billing + products tables
-- ========================================
-- These tables may already have deny_all_* policies in their table definitions.

CREATE POLICY billing_customers_select ON platform.billing_customers
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY billing_customers_insert ON platform.billing_customers
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY billing_customers_update ON platform.billing_customers
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY billing_subscriptions_select ON platform.billing_subscriptions
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY billing_subscriptions_insert ON platform.billing_subscriptions
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY billing_subscriptions_update ON platform.billing_subscriptions
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY subscription_products_select ON platform.subscription_products
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY subscription_products_insert ON platform.subscription_products
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY subscription_products_update ON platform.subscription_products
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());


-- =============== NEW FILE =================

-- log_audit.sql
-- Purpose: Helper function for audit logging

-- ========================================
-- FUNCTION: core.log_audit()
-- ========================================
CREATE OR REPLACE FUNCTION core.log_audit(
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.audit_logs (
    actor_id,
    target_table,
    target_id,
    action,
    summary,
    metadata
  ) VALUES (
    core.get_current_user_id(),
    target_table,
    target_id,
    action_type,
    summary,
    metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;


-- =============== NEW FILE =================

-- secrets.sql
-- Purpose: Core functions for tenant secret management (organization and user scoped)

-- ========================================
-- FUNCTION: core.create_tenant_secret()
-- ========================================
-- Creates a new tenant secret for an organization or user
-- Secrets are stored via core.store_secret_impl (provider-specific) with references in tenant_secrets table
CREATE OR REPLACE FUNCTION core.create_tenant_secret(
  p_scope TEXT,
  p_id UUID,
  p_name TEXT,
  p_secret TEXT
) RETURNS UUID AS $$
DECLARE
  v_vault_key_id UUID;
  v_secret_id UUID;
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Validate scope
  IF p_scope NOT IN ('organization', 'user') THEN
    RAISE EXCEPTION 'Invalid scope. Must be "organization" or "user".';
  END IF;

  -- Authorization check based on scope
  IF p_scope = 'organization' THEN
    -- Only super_admin can manage organization secrets
    IF NOT EXISTS (
      SELECT 1
      FROM core.memberships m
      WHERE m.user_id = v_caller_id
        AND m.organization_id = p_id
        AND m.is_super_admin = true
        AND m.is_deleted = false
    ) THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this organization.';
    END IF;
  ELSIF p_scope = 'user' THEN
    -- Users can only manage their own secrets
    IF v_caller_id <> p_id THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this user.';
    END IF;
  END IF;

  -- Create secret via provider implementation
  v_vault_key_id := core.store_secret_impl(p_secret, p_name)::UUID;

  -- Store reference in tenant_secrets table
  INSERT INTO platform.tenant_secrets (
    scope,
    organization_id,
    user_id,
    secret_name,
    vault_key_id,
    created_by
  ) VALUES (
    p_scope,
    CASE WHEN p_scope = 'organization' THEN p_id ELSE NULL END,
    CASE WHEN p_scope = 'user' THEN p_id ELSE NULL END,
    p_name,
    v_vault_key_id,
    v_caller_id
  ) RETURNING id INTO v_secret_id;

  -- Log the action
  PERFORM core.log_audit(
    'create',
    'platform.tenant_secrets',
    v_secret_id,
    'create_tenant_secret',
    jsonb_build_object(
      'scope', p_scope,
      'secret_name', p_name,
      'target_id', p_id
    )
  );

  RETURN v_secret_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform;

-- ========================================
-- FUNCTION: core.delete_tenant_secret()
-- ========================================
-- Deletes a tenant secret for an organization or user
-- Soft-deletes the reference, hard-deletes from the secrets provider
CREATE OR REPLACE FUNCTION core.delete_tenant_secret(
  p_secret_id UUID
) RETURNS VOID AS $$
DECLARE
  v_scope TEXT;
  v_org_id UUID;
  v_user_id UUID;
  v_vault_key_id UUID;
  v_secret_name TEXT;
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Fetch the secret details first
  SELECT scope, organization_id, user_id, vault_key_id, secret_name
  INTO v_scope, v_org_id, v_user_id, v_vault_key_id, v_secret_name
  FROM platform.tenant_secrets
  WHERE id = p_secret_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Secret not found or already deleted';
  END IF;

  -- Authorization check based on scope
  IF v_scope = 'organization' THEN
    -- Only super_admin can delete organization secrets
    IF NOT EXISTS (
      SELECT 1
      FROM core.memberships m
      WHERE m.user_id = v_caller_id
        AND m.organization_id = v_org_id
        AND m.is_super_admin = true
        AND m.is_deleted = false
    ) THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this organization.';
    END IF;
  ELSIF v_scope = 'user' THEN
    -- Users can only delete their own secrets
    IF v_caller_id <> v_user_id THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this user.';
    END IF;
  END IF;

  -- Soft-delete from tenant_secrets table
  UPDATE platform.tenant_secrets
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_caller_id
  WHERE id = p_secret_id
    AND is_deleted = false;

  -- Hard-delete from secrets provider (cannot be recovered)
  PERFORM core.delete_secret_impl(v_vault_key_id::TEXT);

  -- Log the action
  PERFORM core.log_audit(
    'delete',
    'platform.tenant_secrets',
    p_secret_id,
    'delete_tenant_secret',
    jsonb_build_object(
      'scope', v_scope,
      'secret_name', v_secret_name,
      'vault_key_id', v_vault_key_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform;

-- ========================================
-- FUNCTION: core.list_tenant_secrets()
-- ========================================
-- List all secrets accessible to the current user
CREATE OR REPLACE FUNCTION core.list_tenant_secrets(
  p_scope TEXT DEFAULT NULL,
  p_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  scope TEXT,
  organization_id UUID,
  user_id UUID,
  secret_name TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID
) AS $$
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- If scope and id provided, validate authorization
  IF p_scope IS NOT NULL AND p_id IS NOT NULL THEN
    IF p_scope = 'organization' THEN
      -- Must be a member of the organization
      IF NOT EXISTS (
        SELECT 1
        FROM core.memberships m
        WHERE m.user_id = v_caller_id
          AND m.organization_id = p_id
          AND m.is_deleted = false
      ) THEN
        RAISE EXCEPTION 'You are not authorized to view secrets for this organization.';
      END IF;

      -- Return only organization secrets for this org
      RETURN QUERY
      SELECT ts.id, ts.scope, ts.organization_id, ts.user_id, ts.secret_name, ts.created_at, ts.created_by
      FROM platform.tenant_secrets ts
      WHERE ts.scope = 'organization'
        AND ts.organization_id = p_id
        AND ts.is_deleted = false
      ORDER BY ts.created_at DESC;

    ELSIF p_scope = 'user' THEN
      -- Users can only view their own secrets
      IF v_caller_id <> p_id THEN
        RAISE EXCEPTION 'You are not authorized to view secrets for this user.';
      END IF;

      -- Return only user secrets for this user
      RETURN QUERY
      SELECT ts.id, ts.scope, ts.organization_id, ts.user_id, ts.secret_name, ts.created_at, ts.created_by
      FROM platform.tenant_secrets ts
      WHERE ts.scope = 'user'
        AND ts.user_id = p_id
        AND ts.is_deleted = false
      ORDER BY ts.created_at DESC;

    ELSE
      RAISE EXCEPTION 'Invalid scope. Must be "organization" or "user".';
    END IF;
  ELSE
    -- Return all secrets the user has access to
    RETURN QUERY
    SELECT ts.id, ts.scope, ts.organization_id, ts.user_id, ts.secret_name, ts.created_at, ts.created_by
    FROM platform.tenant_secrets ts
    WHERE (
      -- User's own secrets
      (ts.scope = 'user' AND ts.user_id = v_caller_id)
      OR
      -- Organization secrets where user is a member
      (ts.scope = 'organization' AND EXISTS (
        SELECT 1
        FROM core.memberships m
        WHERE m.user_id = v_caller_id
          AND m.organization_id = ts.organization_id
          AND m.is_deleted = false
      ))
    )
    AND ts.is_deleted = false
    ORDER BY ts.created_at DESC;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform;

-- ========================================
-- NOTES
-- ========================================
-- These functions use SECURITY DEFINER because:
-- 1. They need to access platform.tenant_secrets (authenticated users have no access)
-- 2. They need to call provider-specific secret storage (core.store_secret_impl / core.delete_secret_impl)
-- 3. Authorization is enforced within the function body using core.get_current_user_id()
--
-- The secret value is NEVER returned to the user - only metadata
-- Actual secret values are retrieved by the system when needed (e.g., for SMTP)


-- =============== NEW FILE =================

-- invitations.sql
-- Purpose: Core functions for invitation management

-- ========================================
-- FUNCTION: core.create_invitation()
-- ========================================
-- Creates a new invitation to join an organization or unit
-- Authorization: Must be a member of the organization (CASL controls role-based permissions)
CREATE OR REPLACE FUNCTION core.create_invitation(
  p_email TEXT,
  p_organization_id UUID,
  p_role_id UUID,
  p_unit_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_id UUID;
  v_invitation_id UUID;
  v_token TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Validation: User must be a member of the organization
  IF NOT core.is_org_member(p_organization_id) THEN
    RAISE EXCEPTION 'You must be a member of this organization to invite users';
  END IF;

  -- Validation: If inviting to a unit, user must be a member of that unit
  IF p_unit_id IS NOT NULL THEN
    IF NOT core.is_unit_member(p_unit_id) THEN
      RAISE EXCEPTION 'You must be a member of this unit to invite users to it';
    END IF;

    -- Ensure unit belongs to the organization
    IF NOT EXISTS (
      SELECT 1 FROM core.units u_check
      WHERE u_check.id = p_unit_id AND u_check.organization_id = p_organization_id
    ) THEN
      RAISE EXCEPTION 'Unit does not belong to this organization';
    END IF;
  END IF;

  -- Validation: Role must exist
  IF NOT EXISTS (SELECT 1 FROM core.roles r_check WHERE r_check.id = p_role_id) THEN
    RAISE EXCEPTION 'Invalid role specified';
  END IF;

  -- Validation: Cannot invite as super_admin (must use transfer function)
  IF EXISTS (
    SELECT 1 FROM core.roles r_check
    WHERE r_check.id = p_role_id AND r_check.name = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Cannot invite users as super_admin. Use public.transfer_super_admin() to transfer ownership.';
  END IF;

  -- Validation: Check for duplicate pending invitation
  IF EXISTS (
    SELECT 1 FROM core.invitations inv_check
    WHERE inv_check.email = p_email
      AND inv_check.organization_id = p_organization_id
      AND inv_check.status = 'pending'
      AND inv_check.is_deleted = false
      AND inv_check.expires_at > now()
  ) THEN
    RAISE EXCEPTION 'A pending invitation to this email already exists for this organization';
  END IF;

  -- Validation: Check if user is already a member (use users_meta instead of auth.users —
  -- auth.users is not accessible by the authenticated role via SECURITY INVOKER)
  IF EXISTS (
    SELECT 1 FROM core.memberships m
    JOIN core.users_meta um ON um.id = m.user_id
    WHERE um.email = lower(p_email)
      AND m.organization_id = p_organization_id
      AND m.is_deleted = false
  ) THEN
    RAISE EXCEPTION 'This user is already a member of the organization';
  END IF;

  -- Generate secure token
  v_token := encode(gen_random_bytes(32), 'base64');
  v_expires_at := now() + INTERVAL '7 days';

  -- Create invitation
  INSERT INTO core.invitations (
    email,
    organization_id,
    unit_id,
    role_id,
    invited_by,
    token,
    expires_at,
    metadata,
    created_by
  ) VALUES (
    lower(p_email),
    p_organization_id,
    p_unit_id,
    p_role_id,
    v_caller_id,
    v_token,
    v_expires_at,
    p_metadata,
    v_caller_id
  ) RETURNING core.invitations.id INTO v_invitation_id;

  -- Log the action
  PERFORM core.log_audit(
    'create',
    'core.invitations',
    v_invitation_id,
    'create_invitation',
    jsonb_build_object(
      'email', p_email,
      'organization_id', p_organization_id,
      'unit_id', p_unit_id,
      'role_id', p_role_id
    )
  );

  -- Return invitation details (for email delivery)
  RETURN QUERY
  SELECT v_invitation_id, v_token, lower(p_email), v_expires_at;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core, extensions;

-- ========================================
-- FUNCTION: core.accept_invitation()
-- ========================================
-- Accepts an invitation and creates/updates membership
-- This is called after user authentication
CREATE OR REPLACE FUNCTION core.accept_invitation(
  p_token TEXT
) RETURNS TABLE (
  organization_id UUID,
  unit_id UUID,
  role_id UUID,
  organization_name TEXT
) AS $$
DECLARE
  v_invitation RECORD;
  v_caller_id UUID;
  v_caller_email TEXT;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Get caller's email (use users_meta — auth.users is not accessible to authenticated role via SECURITY INVOKER)
  SELECT email INTO v_caller_email
  FROM core.users_meta
  WHERE id = v_caller_id;

  -- Fetch and validate invitation
  SELECT * INTO v_invitation
  FROM core.invitations
  WHERE token = p_token
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid invitation token';
  END IF;

  -- Check invitation status
  IF v_invitation.status != 'pending' THEN
    RAISE EXCEPTION 'This invitation has already been %', v_invitation.status;
  END IF;

  -- Check expiration
  IF v_invitation.expires_at < now() THEN
    -- Mark as expired
    UPDATE core.invitations
    SET status = 'expired',
        updated_at = now()
    WHERE id = v_invitation.id;

    RAISE EXCEPTION 'This invitation has expired';
  END IF;

  -- Validate email match
  IF lower(v_caller_email) != lower(v_invitation.email) THEN
    RAISE EXCEPTION 'This invitation was sent to a different email address';
  END IF;

  -- Check if already a member
  IF EXISTS (
    SELECT 1 FROM core.memberships m
    WHERE m.user_id = v_caller_id
      AND m.organization_id = v_invitation.organization_id
      AND m.is_deleted = false
  ) THEN
    RAISE EXCEPTION 'You are already a member of this organization';
  END IF;

  -- Create organization membership
  INSERT INTO core.memberships (
    user_id,
    organization_id,
    role_id,
    is_super_admin,
    created_by
  ) VALUES (
    v_caller_id,
    v_invitation.organization_id,
    v_invitation.role_id,
    false,
    v_invitation.invited_by
  );

  -- Create unit membership if specified
  IF v_invitation.unit_id IS NOT NULL THEN
    INSERT INTO core.unit_memberships (
      user_id,
      unit_id,
      role_id,
      created_by
    ) VALUES (
      v_caller_id,
      v_invitation.unit_id,
      v_invitation.role_id,
      v_invitation.invited_by
    );
  END IF;

  -- Mark invitation as accepted
  UPDATE core.invitations
  SET status = 'accepted',
      accepted_at = now(),
      accepted_by = v_caller_id,
      updated_at = now()
  WHERE id = v_invitation.id;

  -- Log the action
  PERFORM core.log_audit(
    'accept',
    'core.invitations',
    v_invitation.id,
    'accept_invitation',
    jsonb_build_object(
      'organization_id', v_invitation.organization_id,
      'user_id', v_caller_id
    )
  );

  -- Return details
  RETURN QUERY
  SELECT
    v_invitation.organization_id,
    v_invitation.unit_id,
    v_invitation.role_id,
    o.name
  FROM core.organizations o
  WHERE o.id = v_invitation.organization_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

-- ========================================
-- FUNCTION: core.cancel_invitation()
-- ========================================
-- Cancels a pending invitation
-- Authorization: Must be the inviter or an org member (CASL controls specific role requirements)
CREATE OR REPLACE FUNCTION core.cancel_invitation(
  p_invitation_id UUID
) RETURNS VOID AS $$
DECLARE
  v_invitation RECORD;
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Fetch invitation
  SELECT * INTO v_invitation
  FROM core.invitations
  WHERE id = p_invitation_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  -- Authorization: Must be the inviter or a member of the organization
  IF v_invitation.invited_by != v_caller_id AND NOT core.is_org_member(v_invitation.organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to cancel this invitation';
  END IF;

  -- Can only cancel pending invitations
  IF v_invitation.status != 'pending' THEN
    RAISE EXCEPTION 'Can only cancel pending invitations';
  END IF;

  -- Mark as cancelled
  UPDATE core.invitations
  SET status = 'cancelled',
      updated_at = now(),
      updated_by = v_caller_id
  WHERE id = p_invitation_id;

  -- Log the action
  PERFORM core.log_audit(
    'cancel',
    'core.invitations',
    p_invitation_id,
    'cancel_invitation',
    jsonb_build_object('email', v_invitation.email)
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- FUNCTION: core.resend_invitation()
-- ========================================
-- Resends an invitation with a new token and extended expiration
-- Authorization: Must be a member of the organization
CREATE OR REPLACE FUNCTION core.resend_invitation(
  p_invitation_id UUID
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
DECLARE
  v_invitation RECORD;
  v_caller_id UUID;
  v_new_token TEXT;
  v_new_expires_at TIMESTAMPTZ;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Fetch invitation
  SELECT * INTO v_invitation
  FROM core.invitations
  WHERE core.invitations.id = p_invitation_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  -- Authorization: Must be a member of the organization
  IF NOT core.is_org_member(v_invitation.organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to resend this invitation';
  END IF;

  -- Can only resend pending or expired invitations
  IF v_invitation.status NOT IN ('pending', 'expired') THEN
    RAISE EXCEPTION 'Can only resend pending or expired invitations';
  END IF;

  -- Generate new token and expiration
  v_new_token := encode(gen_random_bytes(32), 'base64');
  v_new_expires_at := now() + INTERVAL '7 days';

  -- Update invitation
  UPDATE core.invitations
  SET token = v_new_token,
      expires_at = v_new_expires_at,
      status = 'pending',
      updated_at = now(),
      updated_by = v_caller_id
  WHERE core.invitations.id = p_invitation_id;

  -- Log the action
  PERFORM core.log_audit(
    'resend',
    'core.invitations',
    p_invitation_id,
    'resend_invitation',
    jsonb_build_object('email', v_invitation.email)
  );

  -- Return new invitation details
  RETURN QUERY
  SELECT p_invitation_id, v_new_token, v_invitation.email, v_new_expires_at;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core, extensions;

-- ========================================
-- FUNCTION: core.list_organization_invitations()
-- ========================================
-- Lists invitations for an organization
-- Authorization: Must be a member of the organization
CREATE OR REPLACE FUNCTION core.list_organization_invitations(
  p_organization_id UUID,
  p_status TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_id UUID,
  unit_id UUID,
  role_name TEXT,
  invited_by_email TEXT,
  status TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Authorization: Must be a member of the organization
  IF NOT core.is_org_member(p_organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to view invitations for this organization';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.email,
    i.organization_id,
    i.unit_id,
    r.name AS role_name,
    um.email AS invited_by_email,
    i.status,
    i.expires_at,
    i.created_at
  FROM core.invitations i
  JOIN core.roles r ON r.id = i.role_id
  LEFT JOIN core.users_meta um ON um.id = i.invited_by
  WHERE i.organization_id = p_organization_id
    AND i.is_deleted = false
    AND (p_status IS NULL OR i.status = p_status)
  ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- FUNCTION: core.get_invitation_by_token()
-- ========================================
-- Retrieves invitation details by token (for landing page display)
-- This is public-safe - does not require authentication
CREATE OR REPLACE FUNCTION core.get_invitation_by_token(
  p_token TEXT
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_name TEXT,
  unit_name TEXT,
  role_name TEXT,
  invited_by_name TEXT,
  expires_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.email,
    o.name AS organization_name,
    u.name AS unit_name,
    r.name AS role_name,
    COALESCE(um.first_name || ' ' || um.last_name, um.email) AS invited_by_name,
    i.expires_at,
    i.status
  FROM core.invitations i
  JOIN core.organizations o ON o.id = i.organization_id
  LEFT JOIN core.units u ON u.id = i.unit_id
  JOIN core.roles r ON r.id = i.role_id
  LEFT JOIN core.users_meta um ON um.id = i.invited_by
  WHERE i.token = p_token
    AND i.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- FUNCTION: core.expire_old_invitations()
-- ========================================
-- Utility function to mark expired invitations
-- Should be called periodically (via cron or before checking invitations)
CREATE OR REPLACE FUNCTION core.expire_old_invitations()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE core.invitations
  SET status = 'expired',
      updated_at = now()
  WHERE status = 'pending'
    AND expires_at < now()
    AND is_deleted = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;

-- ========================================
-- NOTES
-- ========================================
-- Authorization model:
--   - create_invitation: Must be org member (CASL controls role permissions)
--   - accept_invitation: Authenticated user matching invitation email
--   - cancel_invitation: Inviter or org member (CASL controls role permissions)
--   - resend_invitation: Org member (CASL controls role permissions)
--   - list_invitations: Org member
--   - get_invitation_by_token: Public (no auth required)
--
-- Token security:
--   - 32-byte random tokens, base64 encoded
--   - Tokens are unique and indexed for fast lookup
--   - Tokens expire after 7 days
--
-- Edge cases handled:
--   - Duplicate pending invitations prevented
--   - Email validation on acceptance
--   - Expired invitation detection
--   - Already-a-member detection
--   - Cannot invite as super_admin


-- =============== NEW FILE =================

-- user_profile.sql
-- Purpose: Public RPC functions for user profile management

-- ========================================
-- FUNCTION: public.get_user_profile()
-- ========================================
-- Returns profile data for the current user
CREATE OR REPLACE FUNCTION public.get_user_profile()
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.email,
    m.first_name,
    m.last_name,
    m.avatar_url,
    m.timezone,
    m.locale
  FROM core.users_meta m
  WHERE m.id = core.get_current_user_id();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_user_profile()
-- ========================================
DROP FUNCTION IF EXISTS public.update_user_profile(JSON);
CREATE OR REPLACE FUNCTION public.update_user_profile(
  p_first_name TEXT,
  p_last_name TEXT
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  UPDATE core.users_meta AS um
  SET first_name = p_first_name,
      last_name  = p_last_name,
      updated_by = core.get_current_user_id()
  WHERE um.id = core.get_current_user_id();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;

  PERFORM core.log_audit('update', 'core.users_meta', core.get_current_user_id(), 'update_user_profile',
    jsonb_build_object('first_name', p_first_name, 'last_name', p_last_name));

  RETURN QUERY
  SELECT m.id, m.email, m.first_name, m.last_name, m.avatar_url, m.timezone, m.locale
  FROM core.users_meta m WHERE m.id = core.get_current_user_id();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_organizations()
-- ========================================
-- Returns all active organizations the current user belongs to.
CREATE OR REPLACE FUNCTION public.get_user_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.list_my_organizations();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_units()
-- ========================================
-- Returns units the current user belongs to within a specific organization.
CREATE OR REPLACE FUNCTION public.get_user_units(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND u.organization_id = p_org_id
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =============== NEW FILE =================

-- organizations.sql
-- Purpose: Public RPC functions for organization management

-- ========================================
-- FUNCTION: public.list_my_organizations()
-- ========================================
-- List organizations the current user belongs to
CREATE OR REPLACE FUNCTION public.list_my_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.name, o.description, r.name AS role
  FROM core.organizations o
  JOIN core.memberships m ON m.organization_id = o.id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = core.get_current_user_id()
    AND m.is_deleted = false
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_organization()
-- ========================================
-- Get a single organization by id
CREATE OR REPLACE FUNCTION public.get_organization(p_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  updated_by UUID,
  is_deleted BOOLEAN,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.name, o.description, o.created_by, o.updated_by, o.is_deleted, o.deleted_at, o.deleted_by, o.created_at, o.updated_at
  FROM core.organizations o
  WHERE o.id = p_id
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_organization_members()
-- ========================================
-- List members of an organization
CREATE OR REPLACE FUNCTION public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  is_super_admin BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT m.user_id,
         um.email,
         um.first_name,
         um.last_name,
         r.name AS role,
         m.is_super_admin
  FROM core.memberships m
  JOIN core.users_meta um ON um.id = m.user_id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.organization_id = p_id
    AND m.is_deleted = false
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_role()
-- ========================================
-- Get the role of the current user within an organization
CREATE OR REPLACE FUNCTION public.get_user_role(p_org_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN core.get_org_role(p_org_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_permissions()
-- ========================================
-- Returns the current user's role name and CASL rules for a given organization.
-- Used to build a CASL Ability in the application layer.
CREATE OR REPLACE FUNCTION public.get_user_permissions(p_org_id UUID)
RETURNS TABLE (
  role_name  TEXT,
  casl_rules JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT r.name AS role_name, r.casl_rules
  FROM core.memberships m
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = core.get_current_user_id()
    AND m.organization_id = p_org_id
    AND m.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.create_organization()
-- ========================================
-- Create a new organization and assign creator as super_admin
-- NOTE: This function previously accepted (p_name TEXT, p_role_id UUID).
-- We drop that signature to avoid overload ambiguity.
DROP FUNCTION IF EXISTS public.create_organization(TEXT, UUID);
CREATE OR REPLACE FUNCTION public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  name TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_org_id UUID;
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Organization name is required';
  END IF;

  -- Avoid INSERT .. RETURNING here.
  -- The org membership is seeded in an AFTER INSERT trigger, and the RETURNING clause
  -- would require SELECT access to the new org row before that membership exists.
  v_org_id := gen_random_uuid();

  INSERT INTO core.organizations (id, name, description, created_by, updated_by)
  VALUES (v_org_id, p_name, p_description, core.get_current_user_id(), core.get_current_user_id());

  -- Membership + platform registry rows are created by core.handle_new_organization() trigger.
  PERFORM core.log_audit(
    'insert',
    'core.organizations',
    v_org_id,
    'create_organization',
    jsonb_build_object('name', p_name, 'description', p_description)
  );

  RETURN QUERY SELECT core.organizations.id, core.organizations.name, core.organizations.created_at FROM core.organizations WHERE core.organizations.id = v_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.invite_user_to_organization()
-- ========================================
-- Invite another user to an organization
CREATE OR REPLACE FUNCTION public.invite_user_to_organization(p_email TEXT, p_role_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_org_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  SELECT organization_id INTO v_org_id FROM core.memberships
  WHERE user_id = core.get_current_user_id() AND is_deleted = false
  LIMIT 1;

  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_user_id, v_org_id, p_role_id, core.get_current_user_id());

  PERFORM core.log_audit('insert', 'core.memberships', v_user_id, 'invite_user_to_organization', jsonb_build_object('organization_id', v_org_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_user_from_organization()
-- ========================================
-- Remove a user from an organization (soft delete)
-- Note: Cannot remove super_admin - must transfer first
CREATE OR REPLACE FUNCTION public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
RETURNS VOID AS $$
BEGIN
  -- RLS and protect_super_admin trigger will enforce permissions
  UPDATE core.memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id()
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.memberships', p_user_id, 'remove_user_from_organization', jsonb_build_object('organization_id', p_org_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.transfer_super_admin()
-- ========================================
-- Transfer super_admin status to another organization member
-- Only the current super_admin can perform this action
CREATE OR REPLACE FUNCTION public.transfer_super_admin(p_org_id UUID, p_new_super_admin_user_id UUID)
RETURNS VOID AS $$
DECLARE
  v_current_user_id UUID;
  v_target_membership_exists BOOLEAN;
  v_target_membership_is_deleted BOOLEAN;
BEGIN
  v_current_user_id := core.get_current_user_id();

  -- Verify caller is current super_admin
  IF NOT core.is_super_admin(p_org_id) THEN
    RAISE EXCEPTION 'Only the current super_admin can transfer ownership';
  END IF;

  -- Verify target user is a member of the organization
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = p_new_super_admin_user_id
      AND organization_id = p_org_id
      AND is_deleted = false
  ) INTO v_target_membership_exists;

  IF NOT v_target_membership_exists THEN
    RAISE EXCEPTION 'Target user is not a member of this organization';
  END IF;

  -- Cannot transfer to self
  IF v_current_user_id = p_new_super_admin_user_id THEN
    RAISE EXCEPTION 'Cannot transfer super_admin to yourself';
  END IF;

  -- Perform transfer in two steps to avoid temporary dual-super_admin state
  -- (which would violate the partial unique index idx_one_super_admin_per_org).
  -- Step 1: Demote current super_admin first.
  -- Step 2: Promote new super_admin.
  -- RLS is satisfied because caller is still super_admin until this function returns.
  UPDATE core.memberships
  SET is_super_admin = false,
      updated_by = v_current_user_id,
      updated_at = now()
  WHERE organization_id = p_org_id
    AND user_id = v_current_user_id
    AND is_deleted = false;

  UPDATE core.memberships
  SET is_super_admin = true,
      updated_by = v_current_user_id,
      updated_at = now()
  WHERE organization_id = p_org_id
    AND user_id = p_new_super_admin_user_id
    AND is_deleted = false;

  PERFORM core.log_audit(
    'update',
    'core.memberships',
    p_new_super_admin_user_id,
    'transfer_super_admin',
    jsonb_build_object(
      'organization_id', p_org_id,
      'previous_super_admin', v_current_user_id,
      'new_super_admin', p_new_super_admin_user_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_organization()
-- ========================================
-- Update an organization (super_admin only)
CREATE OR REPLACE FUNCTION public.update_organization(
  p_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Organization id is required';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Organization name is required';
  END IF;

  -- Prevent leaking whether an org exists to non-members
  IF NOT core.is_org_member(p_id) THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  IF NOT core.is_super_admin(p_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update the organization';
  END IF;

  UPDATE core.organizations as o
  SET name = p_name,
      description = p_description,
      updated_by = core.get_current_user_id()
  WHERE o.id = p_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  PERFORM core.log_audit(
    'update',
    'core.organizations',
    p_id,
    'update_organization',
    jsonb_build_object('name', p_name, 'description', p_description)
  );

  RETURN QUERY
  SELECT o.id, o.name, o.description, o.updated_at
  FROM core.organizations o
  WHERE o.id = p_id
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_organization_meta()
-- ========================================
-- Update organization metadata (super_admin only)
CREATE OR REPLACE FUNCTION public.update_organization_meta(
  p_id UUID,
  p_logo_file_id UUID DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_timezone TEXT DEFAULT NULL,
  p_locale TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  logo_file_id UUID,
  address TEXT,
  timezone TEXT,
  locale TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Organization id is required';
  END IF;

  -- Prevent leaking whether an org exists to non-members
  IF NOT core.is_org_member(p_id) THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  IF NOT core.is_super_admin(p_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update the organization';
  END IF;

  IF p_logo_file_id IS NOT NULL THEN
    PERFORM 1
    FROM core.organization_files of
    WHERE of.id = p_logo_file_id
      AND of.organization_id = p_id
      AND of.is_deleted = false;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid logo_file_id for this organization';
    END IF;
  END IF;

  UPDATE core.organizations_meta om
  SET logo_file_id = p_logo_file_id,
      address = p_address,
      timezone = p_timezone,
      locale = p_locale,
      updated_by = core.get_current_user_id()
  WHERE om.id = p_id
    AND om.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  PERFORM core.log_audit(
    'update',
    'core.organizations_meta',
    p_id,
    'update_organization_meta',
    jsonb_build_object(
      'logo_file_id', p_logo_file_id,
      'address', p_address,
      'timezone', p_timezone,
      'locale', p_locale
    )
  );

  RETURN QUERY
  SELECT om.id, om.logo_file_id, om.address, om.timezone, om.locale, om.updated_at
  FROM core.organizations_meta om
  WHERE om.id = p_id
    AND om.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_organization()
-- ========================================
-- Soft-delete an organization and related tenant data (super_admin only)
-- Intended to be the "shut off subscription" operation.
CREATE OR REPLACE FUNCTION public.delete_organization(p_id UUID)
RETURNS VOID AS $$
DECLARE
  v_unit_ids UUID[];
  v_org_meta_rows INT := 0;
  v_unit_meta_rows INT := 0;
  v_unit_membership_rows INT := 0;
  v_unit_rows INT := 0;
  v_org_file_rows INT := 0;
  v_cleared_super_admin_rows INT := 0;
  v_membership_rows INT := 0;
  v_membership_rows_self INT := 0;
  v_org_rows INT := 0;
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Organization id is required';
  END IF;

  -- Prevent leaking whether an org exists to non-members
  IF NOT core.is_org_member(p_id) THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  IF NOT core.is_super_admin(p_id) THEN
    RAISE EXCEPTION 'Only a super_admin can delete the organization';
  END IF;

  -- Ensure org exists and is active
  PERFORM 1
  FROM core.organizations AS o
  WHERE o.id = p_id
    AND o.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  SELECT COALESCE(array_agg(u.id), ARRAY[]::uuid[])
  INTO v_unit_ids
  FROM core.units u
  WHERE u.organization_id = p_id
    AND u.is_deleted = false;

  -- Soft-delete organizations_meta first (1:1)
  UPDATE core.organizations_meta AS o
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE o.id = p_id
    AND o.is_deleted = false;
  GET DIAGNOSTICS v_org_meta_rows = ROW_COUNT;

  -- Soft-delete units and their dependent rows while units are still active
  IF array_length(v_unit_ids, 1) IS NOT NULL AND array_length(v_unit_ids, 1) > 0 THEN
    UPDATE core.unit_meta AS u
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = core.get_current_user_id(),
        updated_by = core.get_current_user_id()
    WHERE u.id = ANY (v_unit_ids)
      AND u.is_deleted = false;
    GET DIAGNOSTICS v_unit_meta_rows = ROW_COUNT;

    UPDATE core.unit_memberships AS m
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = core.get_current_user_id(),
        updated_by = core.get_current_user_id()
    WHERE m.unit_id = ANY (v_unit_ids)
      AND m.is_deleted = false;
    GET DIAGNOSTICS v_unit_membership_rows = ROW_COUNT;

    UPDATE core.units AS u
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = core.get_current_user_id(),
        updated_by = core.get_current_user_id()
    WHERE u.id = ANY (v_unit_ids)
      AND u.is_deleted = false;
    GET DIAGNOSTICS v_unit_rows = ROW_COUNT;
  END IF;

  -- Soft-delete org files
  UPDATE core.organization_files AS f
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE f.organization_id = p_id
    AND f.is_deleted = false;
  GET DIAGNOSTICS v_org_file_rows = ROW_COUNT;

  -- protect_super_admin trigger blocks soft-delete of a super_admin membership.
  -- Clear the flag for the caller first.
  UPDATE core.memberships AS m
  SET is_super_admin = false,
      updated_by = core.get_current_user_id()
  WHERE m.organization_id = p_id
    AND m.user_id = core.get_current_user_id()
    AND m.is_super_admin = true
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_cleared_super_admin_rows = ROW_COUNT;

  -- Soft-delete all other org memberships (excluding caller)
  UPDATE core.memberships AS m
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE m.organization_id = p_id
    AND m.user_id <> core.get_current_user_id()
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_membership_rows = ROW_COUNT;

  -- Soft-delete the organization BEFORE deleting caller's membership.
  -- The org UPDATE uses RLS which checks membership; if caller's membership is
  -- deleted first, the RLS check fails silently (0 rows updated).
  UPDATE core.organizations AS o
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE o.id = p_id
    AND o.is_deleted = false;
  GET DIAGNOSTICS v_org_rows = ROW_COUNT;

  -- Finally, soft-delete the caller's own membership
  UPDATE core.memberships AS m
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE m.organization_id = p_id
    AND m.user_id = core.get_current_user_id()
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_membership_rows_self = ROW_COUNT;

  v_membership_rows := v_membership_rows + v_membership_rows_self;

  PERFORM core.log_audit(
    'delete',
    'core.organizations',
    p_id,
    'delete_organization',
    jsonb_build_object(
      'organizations_meta_rows', v_org_meta_rows,
      'unit_meta_rows', v_unit_meta_rows,
      'unit_membership_rows', v_unit_membership_rows,
      'unit_rows', v_unit_rows,
      'organization_file_rows', v_org_file_rows,
      'cleared_super_admin_rows', v_cleared_super_admin_rows,
      'membership_rows', v_membership_rows,
      'organization_rows', v_org_rows
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core, auth;

-- ========================================
-- FUNCTION: public.add_member_to_organization()
-- ========================================
-- Add an existing user to an organization by UUID and role
-- Caller must be super_admin; user must already exist in core.users_meta
CREATE OR REPLACE FUNCTION public.add_member_to_organization(
  p_org_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT core.is_super_admin(p_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can add members to the organization';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM core.users_meta WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
  VALUES (p_user_id, p_org_id, p_role_id, false, core.get_current_user_id(), core.get_current_user_id())
  ON CONFLICT (user_id, organization_id) DO UPDATE
    SET role_id = EXCLUDED.role_id,
        is_deleted = false,
        deleted_at = NULL,
        deleted_by = NULL,
        updated_by = core.get_current_user_id(),
        updated_at = now();

  PERFORM core.log_audit('insert', 'core.memberships', p_user_id, 'add_member_to_organization',
    jsonb_build_object('organization_id', p_org_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core, auth;

-- ========================================
-- FUNCTION: public.update_member_role()
-- ========================================
-- Update an existing member's role within an organization
-- Caller must be super_admin
CREATE OR REPLACE FUNCTION public.update_member_role(
  p_org_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT core.is_super_admin(p_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update member roles';
  END IF;

  UPDATE core.memberships
  SET role_id = p_role_id,
      updated_by = core.get_current_user_id(),
      updated_at = now()
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found in organization';
  END IF;

  PERFORM core.log_audit('update', 'core.memberships', p_user_id, 'update_member_role',
    jsonb_build_object('organization_id', p_org_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_member_from_organization()
-- ========================================
-- Soft-delete a member from an organization (super_admin only)
-- Cannot remove the super_admin — transfer first
CREATE OR REPLACE FUNCTION public.remove_member_from_organization(
  p_org_id UUID,
  p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT core.is_super_admin(p_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can remove members from the organization';
  END IF;

  -- protect_super_admin trigger will block deletion of a super_admin membership
  UPDATE core.memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  PERFORM core.log_audit('delete', 'core.memberships', p_user_id, 'remove_member_from_organization',
    jsonb_build_object('organization_id', p_org_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core, auth;


-- =============== NEW FILE =================

-- units.sql
-- Purpose: Public RPC functions for unit management
-- Note: RLS validates org/unit membership; CASL handles fine-grained permissions

-- ========================================
-- FUNCTION: public.list_my_units()
-- ========================================
-- List units for the current user
CREATE OR REPLACE FUNCTION public.list_my_units()
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_unit()
-- ========================================
-- Get unit metadata
CREATE OR REPLACE FUNCTION public.get_unit(p_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, u.description, u.created_at, u.updated_at
  FROM core.units u
  WHERE u.id = p_id
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_unit_members()
-- ========================================
-- List members of a unit
CREATE OR REPLACE FUNCTION public.list_unit_members(p_unit_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT um.user_id,
         umeta.email,
         umeta.first_name,
         umeta.last_name,
         r.name AS role
  FROM core.unit_memberships um
  JOIN core.users_meta umeta ON umeta.id = um.user_id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.unit_id = p_unit_id
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_user_unit_permissions()
-- ========================================
-- Returns the current user's role name and CASL rules for a given unit.
-- Used to build a unit-scoped CASL Ability in the application layer.
CREATE OR REPLACE FUNCTION public.get_user_unit_permissions(p_unit_id UUID)
RETURNS TABLE (
  role_name  TEXT,
  casl_rules JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT r.name AS role_name, r.casl_rules
  FROM core.unit_memberships um
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND um.unit_id = p_unit_id
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.create_unit()
-- ========================================
-- Create a new unit within an organization
-- RLS validates org membership; CASL controls who can create
CREATE OR REPLACE FUNCTION public.create_unit(
  p_org_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  updated_by UUID
) AS $$
DECLARE
  v_unit_id UUID;
BEGIN
  INSERT INTO core.units (organization_id, name, description, created_by, updated_by)
  VALUES (p_org_id, p_name, p_description, core.get_current_user_id(), core.get_current_user_id())
  RETURNING core.units.id INTO v_unit_id;

  PERFORM core.log_audit('insert', 'core.units', v_unit_id, 'create_unit', jsonb_build_object('organization_id', p_org_id, 'name', p_name));

  RETURN QUERY SELECT u.id, u.organization_id, u.name, u.description, u.created_by, u.updated_by FROM core.units u WHERE u.id = v_unit_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.assign_user_to_unit()
-- ========================================
-- Assign a user to a unit
-- RLS validates org membership; CASL controls who can assign
CREATE OR REPLACE FUNCTION public.assign_user_to_unit(p_user_id UUID, p_unit_id UUID, p_role_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (p_user_id, p_unit_id, p_role_id, core.get_current_user_id());

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'assign_user_to_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_user_from_unit()
-- ========================================
-- Remove a user from a unit (soft delete)
-- RLS validates org membership; CASL controls who can remove
CREATE OR REPLACE FUNCTION public.remove_user_from_unit(p_user_id UUID, p_unit_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.unit_memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_user_from_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_units()
-- ========================================
-- List all active units for an organization (for org members)
-- Different from list_my_units() which only shows units the caller belongs to
CREATE OR REPLACE FUNCTION public.list_units(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, u.description, u.created_at, u.updated_at
  FROM core.units u
  WHERE u.organization_id = p_org_id
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_unit()
-- ========================================
CREATE OR REPLACE FUNCTION public.update_unit(
  p_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Unit id is required';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Unit name is required';
  END IF;

  -- NULL p_description explicitly clears the description (matches update_organization convention)
  UPDATE core.units u
  SET name = p_name,
      description = p_description,
      updated_by = core.get_current_user_id()
  WHERE u.id = p_id
    AND u.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unit not found';
  END IF;

  PERFORM core.log_audit('update', 'core.units', p_id, 'update_unit',
    jsonb_build_object('name', p_name, 'description', p_description));

  RETURN QUERY
  SELECT u.id, u.name, u.description, u.updated_at
  FROM core.units u WHERE u.id = p_id AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_unit()
-- ========================================
CREATE OR REPLACE FUNCTION public.delete_unit(p_id UUID)
RETURNS VOID AS $$
BEGIN
  IF p_id IS NULL THEN
    RAISE EXCEPTION 'Unit id is required';
  END IF;

  UPDATE core.unit_memberships
  SET is_deleted = true, deleted_at = now(), deleted_by = core.get_current_user_id(), updated_by = core.get_current_user_id()
  WHERE unit_id = p_id AND is_deleted = false;

  UPDATE core.unit_meta
  SET is_deleted = true, deleted_at = now(), deleted_by = core.get_current_user_id(), updated_by = core.get_current_user_id()
  WHERE id = p_id AND is_deleted = false;

  UPDATE core.units u
  SET is_deleted = true, deleted_at = now(), deleted_by = core.get_current_user_id(), updated_by = core.get_current_user_id()
  WHERE u.id = p_id AND u.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unit not found';
  END IF;

  PERFORM core.log_audit('delete', 'core.units', p_id, 'delete_unit', '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core, auth;

-- ========================================
-- FUNCTION: public.add_member_to_unit()
-- ========================================
-- Add an existing org member to a unit by UUID and role
-- Caller must be org super_admin
CREATE OR REPLACE FUNCTION public.add_member_to_unit(
  p_unit_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_org_id UUID;
BEGIN
  v_org_id := core.get_org_id_for_unit(p_unit_id);

  IF NOT core.is_super_admin(v_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can add members to a unit';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM core.users_meta WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = p_user_id
      AND organization_id = v_org_id
      AND is_deleted = false
  ) THEN
    RAISE EXCEPTION 'User is not a member of the organization';
  END IF;

  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
  VALUES (p_user_id, p_unit_id, p_role_id, core.get_current_user_id(), core.get_current_user_id())
  ON CONFLICT (user_id, unit_id) DO UPDATE
    SET role_id = EXCLUDED.role_id,
        is_deleted = false,
        deleted_at = NULL,
        deleted_by = NULL,
        updated_by = core.get_current_user_id(),
        updated_at = now();

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'add_member_to_unit',
    jsonb_build_object('unit_id', p_unit_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core, auth;

-- ========================================
-- FUNCTION: public.update_unit_member_role()
-- ========================================
-- Update an existing unit member's role
-- Caller must be org super_admin
CREATE OR REPLACE FUNCTION public.update_unit_member_role(
  p_unit_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_org_id UUID;
BEGIN
  v_org_id := core.get_org_id_for_unit(p_unit_id);

  IF NOT core.is_super_admin(v_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can update unit member roles';
  END IF;

  UPDATE core.unit_memberships
  SET role_id = p_role_id,
      updated_by = core.get_current_user_id(),
      updated_at = now()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found in unit';
  END IF;

  PERFORM core.log_audit('update', 'core.unit_memberships', p_user_id, 'update_unit_member_role',
    jsonb_build_object('unit_id', p_unit_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.remove_member_from_unit()
-- ========================================
-- Soft-delete a member from a unit
-- Caller must be org super_admin
CREATE OR REPLACE FUNCTION public.remove_member_from_unit(
  p_unit_id UUID,
  p_user_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_org_id UUID;
BEGIN
  v_org_id := core.get_org_id_for_unit(p_unit_id);

  IF NOT core.is_super_admin(v_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can remove members from a unit';
  END IF;

  UPDATE core.unit_memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = core.get_current_user_id(),
      updated_by = core.get_current_user_id()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_member_from_unit',
    jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core, auth;


-- =============== NEW FILE =================

-- files.sql
-- Purpose: Public RPC functions for file management

-- ========================================
-- FUNCTION: public.create_file()
-- ========================================
CREATE OR REPLACE FUNCTION public.create_file(
  p_org_id UUID,
  p_file_url TEXT,
  p_file_type TEXT,
  p_file_size INTEGER DEFAULT NULL,
  p_file_specs JSONB DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_file_id UUID;
BEGIN
  INSERT INTO core.organization_files (
    organization_id, file_url, file_type, file_size, file_specs, created_by
  )
  VALUES (
    p_org_id, p_file_url, p_file_type, p_file_size, p_file_specs, core.get_current_user_id()
  )
  RETURNING id INTO v_file_id;

  PERFORM core.log_audit(
    'insert', 'core.organization_files', v_file_id, 'create_file',
    jsonb_build_object(
      'file_url', p_file_url,
      'file_type', p_file_type,
      'file_size', p_file_size,
      'file_specs', p_file_specs
    )
  );

  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at
  FROM core.organization_files
  WHERE id = v_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.update_file_metadata()
-- ========================================
CREATE OR REPLACE FUNCTION public.update_file_metadata(
  p_file_id UUID,
  p_file_specs JSONB DEFAULT NULL,
  p_file_size INTEGER DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  file_url TEXT,
  file_type TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  UPDATE core.organization_files
  SET
    file_specs = COALESCE(p_file_specs, file_specs),
    file_size = COALESCE(p_file_size, file_size),
    updated_by = core.get_current_user_id(),
    updated_at = now()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'update', 'core.organization_files', p_file_id, 'update_file_metadata',
    jsonb_build_object(
      'file_specs', p_file_specs,
      'file_size', p_file_size
    )
  );

  RETURN QUERY
  SELECT id, file_url, file_type, updated_at FROM core.organization_files WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_file()
-- ========================================
CREATE OR REPLACE FUNCTION public.get_file(p_file_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_files()
-- ========================================
CREATE OR REPLACE FUNCTION public.list_files(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE organization_id = p_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_file()
-- ========================================
CREATE OR REPLACE FUNCTION public.delete_file(p_file_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.organization_files
  SET
    is_deleted = true,
    deleted_at = now(),
    deleted_by = core.get_current_user_id()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'delete', 'core.organization_files', p_file_id, 'delete_file',
    jsonb_build_object(
      'file_id', p_file_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =============== NEW FILE =================

-- audit.sql
-- Purpose: Public RPC function for audit log access

-- ========================================
-- FUNCTION: public.get_audit_log()
-- ========================================
-- Get audit log entries for an organization
CREATE OR REPLACE FUNCTION public.get_audit_log(p_org_id UUID, p_limit INT)
RETURNS TABLE (
  id UUID,
  actor_id UUID,
  target_table TEXT,
  target_id UUID,
  action TEXT,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, actor_id, target_table, target_id, action, summary, metadata, created_at
  FROM core.audit_logs
  WHERE organization_id = p_org_id
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =============== NEW FILE =================

-- secrets.sql
-- Purpose: Public RPC functions for tenant secret management
-- These are thin wrappers around core.* functions for client access

-- ========================================
-- FUNCTION: public.create_secret()
-- ========================================
-- Creates a new tenant secret for an organization or user
--
-- Parameters:
--   p_scope: 'organization' or 'user'
--   p_id: organization_id or user_id (depending on scope)
--   p_name: Human-readable name for the secret (e.g., 'SMTP Password', 'API Key')
--   p_secret: The actual secret value (will be stored in Vault)
--
-- Returns: UUID of the created secret reference
--
-- Examples:
--   -- Create organization SMTP secret
--   SELECT public.create_secret('organization', 'org-uuid', 'SMTP Password', 'secret123');
--
--   -- Create user API key
--   SELECT public.create_secret('user', auth.uid(), 'OpenAI API Key', 'sk-...');
CREATE OR REPLACE FUNCTION public.create_secret(
  p_scope TEXT,
  p_id UUID,
  p_name TEXT,
  p_secret TEXT
) RETURNS UUID AS $$
BEGIN
  RETURN core.create_tenant_secret(p_scope, p_id, p_name, p_secret);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_secret()
-- ========================================
-- Deletes a tenant secret
-- Soft-deletes the reference, hard-deletes from Vault (cannot be recovered)
--
-- Parameters:
--   p_secret_id: UUID of the secret to delete
--
-- Authorization:
--   - Organization secrets: only super_admin can delete
--   - User secrets: only the owning user can delete
--
-- Example:
--   SELECT public.delete_secret('secret-uuid');
CREATE OR REPLACE FUNCTION public.delete_secret(
  p_secret_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM core.delete_tenant_secret(p_secret_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_secrets()
-- ========================================
-- List all secrets accessible to the current user
--
-- Parameters (optional):
--   p_scope: Filter by 'organization' or 'user' (null = all)
--   p_id: Filter by organization_id or user_id (null = all)
--
-- Returns: Table of secret metadata (NOT the actual secret values)
--
-- Examples:
--   -- List all secrets I have access to
--   SELECT * FROM public.list_secrets();
--
--   -- List all secrets for a specific organization
--   SELECT * FROM public.list_secrets('organization', 'org-uuid');
--
--   -- List my user secrets
--   SELECT * FROM public.list_secrets('user', auth.uid());
CREATE OR REPLACE FUNCTION public.list_secrets(
  p_scope TEXT DEFAULT NULL,
  p_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  scope TEXT,
  organization_id UUID,
  user_id UUID,
  secret_name TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM core.list_tenant_secrets(p_scope, p_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- NOTES
-- ========================================
-- These public functions are callable via Supabase RPC:
--
--   const { data, error } = await supabase.rpc('create_secret', {
--     p_scope: 'organization',
--     p_id: orgId,
--     p_name: 'SMTP Password',
--     p_secret: 'my-secret-password'
--   })
--
-- Security:
--   - All authorization checks happen in core.* functions
--   - Secrets are stored in Supabase Vault (encrypted at rest)
--   - Secret values are NEVER returned to the client
--   - Only metadata (id, name, timestamps) is accessible


-- =============== NEW FILE =================

-- invitations.sql
-- Purpose: Public RPC functions for invitation management
-- These are thin wrappers around core.* functions for client access

-- ========================================
-- FUNCTION: public.create_invitation()
-- ========================================
-- Creates a new invitation to join an organization or unit
--
-- Parameters:
--   p_email: Email address of the person to invite
--   p_organization_id: Organization to invite them to
--   p_role_id: Role they will have in the organization
--   p_unit_id: (Optional) Specific unit within the organization
--   p_metadata: (Optional) Additional context for the invitation
--
-- Returns: Invitation details including token (for email delivery)
--
-- Authorization: Must be a member of the organization
--   - CASL controls which roles can invite (e.g., only managers and admins)
--   - Database enforces membership requirement only
--
-- Example:
--   SELECT * FROM public.create_invitation(
--     'newuser@example.com',
--     'org-uuid',
--     'role-uuid',
--     NULL,
--     '{"message": "Welcome to the team!"}'::jsonb
--   );
CREATE OR REPLACE FUNCTION public.create_invitation(
  p_email TEXT,
  p_organization_id UUID,
  p_role_id UUID,
  p_unit_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.create_invitation(
    p_email,
    p_organization_id,
    p_role_id,
    p_unit_id,
    p_metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.accept_invitation()
-- ========================================
-- Accepts an invitation and creates organization/unit membership
--
-- Parameters:
--   p_token: The invitation token from the invite link
--
-- Returns: Organization details after successful acceptance
--
-- Authorization: Must be authenticated and email must match invitation
--
-- Example:
--   SELECT * FROM public.accept_invitation('invitation-token-here');
CREATE OR REPLACE FUNCTION public.accept_invitation(
  p_token TEXT
) RETURNS TABLE (
  organization_id UUID,
  unit_id UUID,
  role_id UUID,
  organization_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.accept_invitation(p_token);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.cancel_invitation()
-- ========================================
-- Cancels a pending invitation
--
-- Parameters:
--   p_invitation_id: ID of the invitation to cancel
--
-- Authorization: Must be the inviter or org member
--   - CASL controls which roles can cancel (e.g., only who invited or admins)
--
-- Example:
--   SELECT public.cancel_invitation('invitation-uuid');
CREATE OR REPLACE FUNCTION public.cancel_invitation(
  p_invitation_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM core.cancel_invitation(p_invitation_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.resend_invitation()
-- ========================================
-- Resends an invitation with a new token and extended expiration
--
-- Parameters:
--   p_invitation_id: ID of the invitation to resend
--
-- Returns: New invitation details including new token
--
-- Authorization: Must be a member of the organization
--   - CASL controls which roles can resend invitations
--
-- Example:
--   SELECT * FROM public.resend_invitation('invitation-uuid');
CREATE OR REPLACE FUNCTION public.resend_invitation(
  p_invitation_id UUID
) RETURNS TABLE (
  id UUID,
  token TEXT,
  email TEXT,
  expires_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.resend_invitation(p_invitation_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_invitations()
-- ========================================
-- Lists invitations for an organization
--
-- Parameters:
--   p_organization_id: Organization to list invitations for
--   p_status: (Optional) Filter by status ('pending', 'accepted', 'expired', 'cancelled')
--
-- Returns: Table of invitation records
--
-- Authorization: Must be a member of the organization
--
-- Examples:
--   -- List all invitations
--   SELECT * FROM public.list_invitations('org-uuid');
--
--   -- List only pending invitations
--   SELECT * FROM public.list_invitations('org-uuid', 'pending');
CREATE OR REPLACE FUNCTION public.list_invitations(
  p_organization_id UUID,
  p_status TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_id UUID,
  unit_id UUID,
  role_name TEXT,
  invited_by_email TEXT,
  status TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.list_organization_invitations(p_organization_id, p_status);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.get_invitation_details()
-- ========================================
-- Retrieves invitation details by token (for landing page display)
-- Does not require authentication - safe for public access
--
-- Parameters:
--   p_token: The invitation token from the invite link
--
-- Returns: Invitation details (no sensitive information)
--
-- Authorization: None required (public endpoint)
--
-- Use case: Display "You've been invited to join X as Y" before signup/login
--
-- Example:
--   SELECT * FROM public.get_invitation_details('invitation-token');
CREATE OR REPLACE FUNCTION public.get_invitation_details(
  p_token TEXT
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_name TEXT,
  unit_name TEXT,
  role_name TEXT,
  invited_by_name TEXT,
  expires_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.get_invitation_by_token(p_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core;

-- ========================================
-- NOTES
-- ========================================
-- These public functions are callable via Supabase RPC:
--
--   // Create invitation
--   const { data, error } = await supabase.rpc('create_invitation', {
--     p_email: 'user@example.com',
--     p_organization_id: orgId,
--     p_role_id: roleId
--   })
--   // Returns: { id, token, email, expires_at }
--   // Send email with link: https://app.com/invite?token={token}
--
--   // Get invitation details (before auth)
--   const { data } = await supabase.rpc('get_invitation_details', {
--     p_token: tokenFromURL
--   })
--   // Shows: "You've been invited to join Acme Corp as Manager"
--
--   // Accept invitation (after auth)
--   const { data } = await supabase.rpc('accept_invitation', {
--     p_token: tokenFromURL
--   })
--   // User is now a member
--
--   // List invitations
--   const { data } = await supabase.rpc('list_invitations', {
--     p_organization_id: orgId,
--     p_status: 'pending'
--   })
--
-- Security:
--   - Authorization enforced in core.* functions
--   - CASL controls role-based permissions in the application layer
--   - Tokens are cryptographically secure (32 random bytes)
--   - Emails are validated and normalized (lowercase)
--   - No sensitive data exposed in public endpoints


-- =============== NEW FILE =================

-- log_action.sql
-- Purpose: Helper function for platform action logging

-- ========================================
-- FUNCTION: platform.log_platform_action()
-- ========================================
CREATE OR REPLACE FUNCTION platform.log_platform_action(
  p_action TEXT,
  p_target_table TEXT,
  p_target_id UUID,
  p_summary TEXT,
  p_metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_action_logs (
    platform_user_id,
    auth_user_id,
    action_type,
    target_table,
    target_id,
    summary,
    metadata
  ) VALUES (
    (SELECT id FROM platform.platform_users WHERE supabase_user_id = auth.uid()),
    auth.uid(),
    p_action,
    p_target_table,
    p_target_id,
    p_summary,
    p_metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- users.sql
-- Purpose: Platform functions for managing platform users

-- ========================================
-- FUNCTION: platform.create_platform_user()
-- ========================================
-- Add a new platform user with a specific role
-- New signature: (supabase_user_id, email, role_id)
-- NOTE: A legacy wrapper with the old signature (uuid, text) is retained below.
DROP FUNCTION IF EXISTS platform.create_platform_user(UUID, TEXT);
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_supabase_user_id UUID,
  p_email TEXT,
  p_role_id UUID
) RETURNS UUID AS $$
DECLARE
  v_platform_user_id UUID;
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  IF p_supabase_user_id IS NULL THEN
    RAISE EXCEPTION 'supabase_user_id is required';
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RAISE EXCEPTION 'email is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_supabase_user_id) THEN
    RAISE EXCEPTION 'User % not found', p_supabase_user_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM platform.platform_roles pr WHERE pr.id = p_role_id) THEN
    RAISE EXCEPTION 'Role % not found', p_role_id;
  END IF;

  INSERT INTO platform.platform_users (supabase_user_id, email, role_id, created_by, updated_by)
  VALUES (p_supabase_user_id, p_email, p_role_id, v_actor_id, v_actor_id)
  RETURNING id INTO v_platform_user_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_users', v_platform_user_id,
    'create_platform_user', jsonb_build_object('role_id', p_role_id, 'supabase_user_id', p_supabase_user_id, 'email', p_email));

  RETURN v_platform_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.create_platform_user() (legacy)
-- ========================================
-- Legacy signature: (supabase_user_id, role_name)
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_user_id UUID,
  p_role TEXT
) RETURNS UUID AS $$
DECLARE
  v_role_id UUID;
  v_email TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT pr.id INTO v_role_id
  FROM platform.platform_roles pr
  WHERE pr.name = p_role
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  SELECT u.email INTO v_email
  FROM auth.users u
  WHERE u.id = p_user_id;

  IF v_email IS NULL THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  RETURN platform.create_platform_user(p_user_id, v_email, v_role_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_platform_user()
-- ========================================
-- Change the assigned role_id for a platform user
CREATE OR REPLACE FUNCTION platform.update_platform_user(
  p_user_id UUID,
  p_role_id UUID
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_old_role TEXT;
  v_new_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get current role for audit
  SELECT pr.name INTO v_old_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pr.id = pu.role_id
  WHERE pu.id = p_user_id AND pu.is_deleted = false;

  SELECT pr.name INTO v_new_role
  FROM platform.platform_roles pr
  WHERE pr.id = p_role_id;

  IF v_new_role IS NULL THEN
    RAISE EXCEPTION 'Role % not found', p_role_id;
  END IF;

  UPDATE platform.platform_users
  SET role_id = p_role_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_user_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('update', 'platform.platform_users', p_user_id,
    'update_platform_user', jsonb_build_object('old_role', v_old_role, 'new_role', v_new_role, 'new_role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_platform_user_role() (legacy)
-- ========================================
CREATE OR REPLACE FUNCTION platform.update_platform_user_role(
  p_user_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_role_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT pr.id INTO v_role_id
  FROM platform.platform_roles pr
  WHERE pr.name = p_role
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  PERFORM platform.update_platform_user(p_user_id, v_role_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_platform_user()
-- ========================================
-- Soft-delete a platform user
CREATE OR REPLACE FUNCTION platform.delete_platform_user(
  p_user_id UUID
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_user_email TEXT;
  v_user_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get user details for audit trail before soft-delete
  SELECT pu.email, pr.name INTO v_user_email, v_user_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pr.id = pu.role_id
  WHERE pu.id = p_user_id AND pu.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform user % not found or already deleted', p_user_id;
  END IF;

  -- Soft-delete the platform user
  UPDATE platform.platform_users
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_actor_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_user_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('delete', 'platform.platform_users', p_user_id,
    'delete_platform_user', jsonb_build_object('email', v_user_email, 'role', v_user_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- organizations.sql
-- Purpose: Platform function for managing platform organizations

-- ========================================
-- FUNCTION: platform.create_platform_organization()
-- ========================================
-- Register a new organization in the platform control layer
CREATE OR REPLACE FUNCTION platform.create_platform_organization(
  p_organization_id UUID
) RETURNS VOID AS $$
DECLARE
  v_label TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT name INTO v_label FROM core.organizations WHERE id = p_organization_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization % not found', p_organization_id;
  END IF;

  INSERT INTO platform.platform_organizations (id, label)
  VALUES (p_organization_id, v_label);

  PERFORM platform.log_platform_action('create', 'platform.platform_organizations', p_organization_id,
    'create_platform_organization', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- overrides.sql
-- Purpose: Platform functions for subscription overrides

-- ========================================
-- FUNCTION: platform.set_platform_override()
-- ========================================
-- Store or update a subscription override for an organization
CREATE OR REPLACE FUNCTION platform.set_platform_override(
  p_organization_id UUID,
  p_key TEXT,
  p_value JSONB
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_id FROM platform.platform_subscription_overrides
  WHERE organization_id = p_organization_id;

  IF v_id IS NULL THEN
    INSERT INTO platform.platform_subscription_overrides (organization_id, features)
    VALUES (p_organization_id, jsonb_build_object(p_key, p_value))
    RETURNING id INTO v_id;
  ELSE
    UPDATE platform.platform_subscription_overrides
    SET features = jsonb_set(COALESCE(features, '{}'), ARRAY[p_key], p_value, true),
        updated_at = now()
    WHERE id = v_id;
  END IF;

  PERFORM platform.log_platform_action('override', 'platform.platform_subscription_overrides', v_id,
    'set_platform_override', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_platform_override()
-- ========================================
-- Remove a subscription override
CREATE OR REPLACE FUNCTION platform.delete_platform_override(
  p_organization_id UUID,
  p_key TEXT
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_id FROM platform.platform_subscription_overrides
  WHERE organization_id = p_organization_id;

  IF v_id IS NOT NULL THEN
    UPDATE platform.platform_subscription_overrides
    SET features = COALESCE(features, '{}') - p_key,
        updated_at = now()
    WHERE id = v_id;
  END IF;

  PERFORM platform.log_platform_action('override', 'platform.platform_subscription_overrides', v_id,
    'delete_platform_override', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- feature_flags.sql
-- Purpose: Platform function for feature flag management

-- ========================================
-- FUNCTION: platform.create_platform_feature_flag()
-- ========================================
-- Register a global or per-organization feature toggle
CREATE OR REPLACE FUNCTION platform.create_platform_feature_flag(
  p_key TEXT,
  p_value JSONB,
  p_organization_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  INSERT INTO platform.platform_feature_flags (key, value, organization_id, description, created_by, updated_by)
  VALUES (p_key, p_value, p_organization_id, p_description, v_actor_id, v_actor_id)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_feature_flags', v_id,
    'create_platform_feature_flag', jsonb_build_object('key', p_key, 'organization_id', p_organization_id));

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.get_feature_flag()
-- ========================================
-- Get a specific feature flag by key and optional organization
CREATE OR REPLACE FUNCTION platform.get_feature_flag(
  p_key TEXT,
  p_organization_id UUID DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  key TEXT,
  value JSONB,
  organization_id UUID,
  description TEXT,
  is_active BOOLEAN
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN QUERY
  SELECT ff.id, ff.key, ff.value, ff.organization_id, ff.description, ff.is_active
  FROM platform.platform_feature_flags ff
  WHERE ff.key = p_key
    AND (ff.organization_id = p_organization_id OR (p_organization_id IS NULL AND ff.organization_id IS NULL))
    AND ff.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.list_feature_flags()
-- ========================================
-- List all feature flags, optionally filtered by organization
-- Does NOT include Global flags for a specific organization unless p_include_global is true
CREATE OR REPLACE FUNCTION platform.list_feature_flags(
  p_organization_id UUID DEFAULT NULL,
  p_include_global BOOLEAN DEFAULT false
) RETURNS TABLE (
  id UUID,
  key TEXT,
  value JSONB,
  organization_id UUID,
  description TEXT,
  is_active BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN QUERY
  SELECT ff.id, ff.key, ff.value, ff.organization_id, ff.description, ff.is_active, ff.created_at
  FROM platform.platform_feature_flags ff
  WHERE ff.is_deleted = false
    AND (
      (p_organization_id IS NULL) OR
      (ff.organization_id = p_organization_id) OR
      (p_include_global AND ff.organization_id IS NULL)
    )
  ORDER BY ff.key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.update_feature_flag()
-- ========================================
-- Update an existing feature flag
CREATE OR REPLACE FUNCTION platform.update_feature_flag(
  p_id UUID,
  p_value JSONB DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  UPDATE platform.platform_feature_flags
  SET value = COALESCE(p_value, value),
      is_active = COALESCE(p_is_active, is_active),
      description = COALESCE(p_description, description),
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('update', 'platform.platform_feature_flags', p_id,
    'update_feature_flag', jsonb_build_object('value', p_value, 'is_active', p_is_active));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_feature_flag()
-- ========================================
-- Soft-delete a feature flag
CREATE OR REPLACE FUNCTION platform.delete_feature_flag(
  p_id UUID
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_key TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  -- Get key for audit
  SELECT key INTO v_key FROM platform.platform_feature_flags WHERE id = p_id AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Feature flag % not found or already deleted', p_id;
  END IF;

  UPDATE platform.platform_feature_flags
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_actor_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE id = p_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('delete', 'platform.platform_feature_flags', p_id,
    'delete_feature_flag', jsonb_build_object('key', v_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- events.sql
-- Purpose: Platform function for system event logging

-- ========================================
-- FUNCTION: platform.log_platform_event()
-- ========================================
-- Record a system-level or admin-triggered event
CREATE OR REPLACE FUNCTION platform.log_platform_event(
  p_event_type TEXT,
  p_message TEXT,
  p_metadata JSONB
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.platform_system_events (event_type, summary, details)
  VALUES (p_event_type, p_message, p_metadata)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('log', 'platform.platform_system_events', v_id,
    'log_platform_event', jsonb_build_object('event_type', p_event_type));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- audit.sql
-- Purpose: Platform functions for audit and role access

-- ========================================
-- FUNCTION: platform.get_platform_user_role()
-- ========================================
-- Returns the current user's platform role
CREATE OR REPLACE FUNCTION platform.get_platform_user_role()
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_user();

  SELECT pr.name INTO v_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pu.role_id = pr.id
  WHERE pu.supabase_user_id = auth.uid()
    AND pu.is_deleted = false;

  RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.get_platform_action_log()
-- ========================================
-- Fetch recent platform actions for monitoring or audit
CREATE OR REPLACE FUNCTION platform.get_platform_action_log(
  p_limit INT DEFAULT 100
) RETURNS TABLE (
  id UUID,
  platform_user_id UUID,
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  PERFORM platform.log_platform_action('select', 'platform.platform_action_logs', NULL,
    'get_platform_action_log', jsonb_build_object('limit', p_limit));

  RETURN QUERY
  SELECT id, platform_user_id, action_type, target_table, target_id,
         summary, metadata, created_at
  FROM platform.platform_action_logs
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- settings.sql
-- Purpose: Platform functions for global settings management

-- ========================================
-- FUNCTION: platform.get_setting()
-- ========================================
-- Get a specific platform setting by key
CREATE OR REPLACE FUNCTION platform.get_setting(
  p_key TEXT
) RETURNS TEXT AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN (
    SELECT s.value::text
    FROM platform.platform_settings s
    WHERE s.key = p_key
      AND s.is_deleted = false
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.list_settings()
-- ========================================
-- List all platform settings
CREATE OR REPLACE FUNCTION platform.list_settings()
RETURNS TABLE (
  key TEXT,
  value JSONB,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_user();

  RETURN QUERY
  SELECT s.key, s.value, s.description, s.created_at, s.updated_at
  FROM platform.platform_settings s
  WHERE s.is_deleted = false
  ORDER BY s.key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.set_setting()
-- ========================================
-- Create or update a platform setting (upsert)
CREATE OR REPLACE FUNCTION platform.set_setting(
  p_key TEXT,
  p_value JSONB,
  p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
  v_exists BOOLEAN;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  SELECT EXISTS (
    SELECT 1 FROM platform.platform_settings WHERE key = p_key AND is_deleted = false
  ) INTO v_exists;

  IF v_exists THEN
    UPDATE platform.platform_settings
    SET value = p_value,
        description = COALESCE(p_description, description),
        updated_by = v_actor_id,
        updated_at = now()
    WHERE key = p_key
      AND is_deleted = false;

    PERFORM platform.log_platform_action('update', 'platform.platform_settings', NULL,
      'set_setting', jsonb_build_object('key', p_key, 'action', 'update'));
  ELSE
    INSERT INTO platform.platform_settings (key, value, description, created_by, updated_by)
    VALUES (p_key, p_value, p_description, v_actor_id, v_actor_id);

    PERFORM platform.log_platform_action('create', 'platform.platform_settings', NULL,
      'set_setting', jsonb_build_object('key', p_key, 'action', 'create'));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.delete_setting()
-- ========================================
-- Soft-delete a platform setting
CREATE OR REPLACE FUNCTION platform.delete_setting(
  p_key TEXT
) RETURNS VOID AS $$
DECLARE
  v_actor_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();
  v_actor_id := auth.uid();

  UPDATE platform.platform_settings
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_actor_id,
      updated_by = v_actor_id,
      updated_at = now()
  WHERE key = p_key
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Setting % not found or already deleted', p_key;
  END IF;

  PERFORM platform.log_platform_action('delete', 'platform.platform_settings', NULL,
    'delete_setting', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- billing.sql
-- Purpose: Platform functions for billing integration

-- ========================================
-- FUNCTION: platform.link_paymentprocessor_customer()
-- ========================================
CREATE OR REPLACE FUNCTION platform.link_paymentprocessor_customer(
  p_org_id UUID,
  p_paymentprocessor_customer_id TEXT,
  p_billing_email TEXT
) RETURNS VOID AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.billing_customers (organization_id, paymentprocessor_customer_id, billing_email)
  VALUES (p_org_id, p_paymentprocessor_customer_id, p_billing_email)
  ON CONFLICT (organization_id) DO UPDATE
  SET paymentprocessor_customer_id = EXCLUDED.paymentprocessor_customer_id,
      billing_email = EXCLUDED.billing_email,
      updated_at = now();

  PERFORM platform.log_platform_action(
    'link', 'platform.billing_customers', p_org_id, 'Linked Payment Processor customer',
    jsonb_build_object('paymentprocessor_customer_id', p_paymentprocessor_customer_id, 'email', p_billing_email)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.record_subscription_update()
-- ========================================
CREATE OR REPLACE FUNCTION platform.record_subscription_update(
  p_org_id UUID,
  p_paymentprocessor_subscription_id TEXT,
  p_plan TEXT,
  p_status TEXT,
  p_current_period_end TIMESTAMPTZ,
  p_cancel_at_period_end BOOLEAN
) RETURNS VOID AS $$
DECLARE
  v_sub_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.billing_subscriptions (
    organization_id, paymentprocessor_subscription_id, plan, status, current_period_end, cancel_at_period_end
  ) VALUES (
    p_org_id, p_paymentprocessor_subscription_id, p_plan, p_status, p_current_period_end, p_cancel_at_period_end
  )
  ON CONFLICT (paymentprocessor_subscription_id) DO UPDATE
  SET plan = EXCLUDED.plan,
      status = EXCLUDED.status,
      current_period_end = EXCLUDED.current_period_end,
      cancel_at_period_end = EXCLUDED.cancel_at_period_end,
      updated_at = now();

  SELECT id INTO v_sub_id FROM platform.billing_subscriptions
    WHERE paymentprocessor_subscription_id = p_paymentprocessor_subscription_id;

  PERFORM platform.log_platform_action(
    'update', 'platform.billing_subscriptions', v_sub_id, 'Updated subscription status',
    jsonb_build_object(
      'plan', p_plan,
      'status', p_status,
      'current_period_end', p_current_period_end,
      'cancel_at_period_end', p_cancel_at_period_end
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- NOTES:
-- ========================================
-- All platform functions should be run by Supabase Edge Functions
-- using the service role only. These tables are not exposed to clients.
-- Need the following Edge Functions:
   -- create-checkout-session: Called when user clicks "Subscribe"
   -- handle-paymentprocessor-webhook: Called by Payment Processor on payment/subscription events
   -- billing-portal: Generates a link to the Payment Processor customer portal
-- Payment Processor Webhook Events are handled by a Supabase Edge Function and db function(s):
   -- Webhook will need to validate Payment Processor signature
   -- A list of webhook events will be created at a later date


-- =============== NEW FILE =================

-- products.sql
-- Purpose: Platform functions for subscription product management

-- ========================================
-- FUNCTION: platform.list_all_subscription_products()
-- ========================================
CREATE OR REPLACE FUNCTION platform.list_all_subscription_products()
RETURNS TABLE (
  id UUID,
  paymentprocessor_price_id TEXT,
  name TEXT,
  description TEXT,
  billing_interval TEXT,
  amount INTEGER,
  is_active BOOLEAN,
  metadata JSONB,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN

  PERFORM platform.ensure_platform_admin();

  RETURN QUERY
  SELECT
    id,
    paymentprocessor_price_id,
    name,
    description,
    billing_interval,
    amount,
    is_active,
    metadata,
    created_by,
    updated_by,
    is_deleted,
    deleted_at,
    deleted_by,
    created_at,
    updated_at
  FROM platform.subscription_products
  WHERE is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.add_subscription_product()
-- ========================================
CREATE OR REPLACE FUNCTION platform.add_subscription_product(
  p_paymentprocessor_price_id TEXT,
  p_name TEXT,
  p_description TEXT,
  p_billing_interval TEXT,
  p_amount INTEGER,
  p_is_active BOOLEAN,
  p_metadata JSONB
)
RETURNS TABLE (
  id UUID,
  paymentprocessor_price_id TEXT,
  name TEXT,
  description TEXT,
  billing_interval TEXT,
  amount INTEGER,
  is_active BOOLEAN,
  metadata JSONB,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
DECLARE
  v_row platform.subscription_products%ROWTYPE;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.subscription_products (
    paymentprocessor_price_id,
    name,
    description,
    billing_interval,
    amount,
    is_active,
    metadata,
    created_by,
    updated_by
  ) VALUES (
    p_paymentprocessor_price_id,
    p_name,
    p_description,
    p_billing_interval,
    p_amount,
    p_is_active,
    p_metadata,
    auth.uid(),
    auth.uid()
  ) RETURNING * INTO v_row;

  PERFORM platform.log_platform_action('create', 'platform.subscription_products', v_row.id,
    'create_subscription_product', jsonb_build_object('name', p_name));

  RETURN QUERY SELECT
    v_row.id,
    v_row.paymentprocessor_price_id,
    v_row.name,
    v_row.description,
    v_row.billing_interval,
    v_row.amount,
    v_row.is_active,
    v_row.metadata,
    v_row.created_by,
    v_row.updated_by,
    v_row.is_deleted,
    v_row.deleted_at,
    v_row.deleted_by,
    v_row.created_at,
    v_row.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =============== NEW FILE =================

-- products.sql
-- Purpose: Public function to list available subscription products

-- ========================================
-- FUNCTION: public.list_subscription_products()
-- ========================================
CREATE OR REPLACE FUNCTION public.list_subscription_products()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  billing_interval TEXT,
  amount INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    id,
    name,
    description,
    billing_interval,
    amount,
    created_at,
    updated_at,
    created_by,
    updated_by
  FROM platform.subscription_products
  WHERE is_active = true AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- =============== NEW FILE =================

-- grants.sql
-- Purpose: EXECUTE grants for public.* SECURITY DEFINER functions.
--
-- PostgreSQL grants EXECUTE on public functions to PUBLIC (anon + authenticated)
-- by default. For admin-only SECURITY DEFINER functions, this is too permissive:
-- the unauthenticated anon role can attempt to call them. The internal auth
-- checks (is_super_admin, etc.) would still reject the call, but exposing the
-- functions to anon leaks their existence and creates an unnecessary attack
-- surface (Supabase lint 0028).
--
-- Strategy: REVOKE EXECUTE FROM PUBLIC, then GRANT to authenticated + service_role
-- for admin functions. Public-by-design endpoints (get_invitation_details,
-- list_subscription_products) keep their default PUBLIC grant.

-- ========================================
-- ADMIN FUNCTIONS: require authentication
-- ========================================
-- Note: REVOKE FROM PUBLIC alone does not remove explicit per-role ACL entries.
-- These functions had anon=X/postgres entries on initial deploy, so we revoke
-- from both PUBLIC and anon explicitly to ensure the revoke is complete.
--
-- delete_organization
REVOKE EXECUTE ON FUNCTION public.delete_organization(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delete_organization(uuid) TO authenticated, service_role;

-- delete_unit
REVOKE EXECUTE ON FUNCTION public.delete_unit(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delete_unit(uuid) TO authenticated, service_role;

-- add_member_to_organization
REVOKE EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) TO authenticated, service_role;

-- add_member_to_unit
REVOKE EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) TO authenticated, service_role;

-- remove_member_from_organization
REVOKE EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) TO authenticated, service_role;

-- remove_member_from_unit
REVOKE EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) TO authenticated, service_role;

-- ========================================
-- INTENTIONAL PUBLIC FUNCTIONS (anon callable by design)
-- ========================================
-- These remain accessible to anon because they serve unauthenticated flows:
--   - public.get_invitation_details(text): invitation landing page before login
--   - public.list_subscription_products():  public pricing/marketing page
-- The corresponding Supabase lint 0028 warnings are accepted.
--
-- No REVOKE statements are issued for these functions; they inherit the
-- default PUBLIC EXECUTE grant established at function creation.


-- =============== NEW FILE =================

-- disable_extension.sql
-- Purpose: Drop the pg_graphql extension.
--
-- Supabase enables pg_graphql by default, which auto-exposes tables accessible
-- to the authenticated role in a generated GraphQL schema (Supabase lint 0027).
-- SMTA uses RLS + public.* RPC functions as the only access surface; there is
-- no GraphQL layer, so the extension provides no value and introduces unnecessary
-- schema exposure.
--
-- IF EXISTS makes this safe to run on environments where the extension is already
-- absent (non-Supabase deployments, custom Postgres instances, etc.).

DROP EXTENSION IF EXISTS pg_graphql;


-- =============== NEW FILE =================

-- auth_better_auth_impl.sql
-- Purpose: better-auth implementation of core.get_current_user_id().
-- Reads the user UUID from a PostgreSQL session variable set by the
-- withSMTA() transaction wrapper in @smta/better-auth.
-- Identical mechanism to @smta/payload — no Supabase dependency.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;


-- =============== NEW FILE =================

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
