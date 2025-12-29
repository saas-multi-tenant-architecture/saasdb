-- 05_triggers.sql
-- Purpose: Verify all required triggers exist

BEGIN;

SELECT plan(12);

-- ========================================
-- TRIGGERS: core.organizations
-- ========================================
SELECT has_trigger('core', 'organizations', 'trg_organizations_updated',
  'Trigger trg_organizations_updated should exist on core.organizations');
SELECT has_trigger('core', 'organizations', 'trg_on_organization_created',
  'Trigger trg_on_organization_created should exist on core.organizations');

-- ========================================
-- TRIGGERS: core.units
-- ========================================
SELECT has_trigger('core', 'units', 'trg_units_updated',
  'Trigger trg_units_updated should exist on core.units');
SELECT has_trigger('core', 'units', 'trg_on_unit_created',
  'Trigger trg_on_unit_created should exist on core.units');

-- ========================================
-- TRIGGERS: core.memberships
-- ========================================
SELECT has_trigger('core', 'memberships', 'trg_memberships_updated',
  'Trigger trg_memberships_updated should exist on core.memberships');
SELECT has_trigger('core', 'memberships', 'trg_protect_super_admin',
  'Trigger trg_protect_super_admin should exist on core.memberships');

-- ========================================
-- TRIGGERS: core.unit_memberships
-- ========================================
SELECT has_trigger('core', 'unit_memberships', 'trg_unit_memberships_updated',
  'Trigger trg_unit_memberships_updated should exist on core.unit_memberships');

-- ========================================
-- TRIGGERS: core.users_meta
-- ========================================
SELECT has_trigger('core', 'users_meta', 'trg_users_meta_updated',
  'Trigger trg_users_meta_updated should exist on core.users_meta');

-- ========================================
-- TRIGGERS: core.unit_meta
-- ========================================
SELECT has_trigger('core', 'unit_meta', 'trg_unit_meta_updated',
  'Trigger trg_unit_meta_updated should exist on core.unit_meta');

-- ========================================
-- TRIGGERS: platform.platform_users
-- ========================================
SELECT has_trigger('platform', 'platform_users', 'trg_platform_users_updated',
  'Trigger trg_platform_users_updated should exist on platform.platform_users');

-- ========================================
-- TRIGGERS: platform.platform_settings
-- ========================================
SELECT has_trigger('platform', 'platform_settings', 'trg_platform_settings_updated',
  'Trigger trg_platform_settings_updated should exist on platform.platform_settings');

-- ========================================
-- TRIGGERS: platform.platform_feature_flags
-- ========================================
SELECT has_trigger('platform', 'platform_feature_flags', 'trg_platform_feature_flags_updated',
  'Trigger trg_platform_feature_flags_updated should exist on platform.platform_feature_flags');

SELECT * FROM finish();

ROLLBACK;
