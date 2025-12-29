-- 04_indexes.sql
-- Purpose: Verify all required indexes exist for performance

BEGIN;

SELECT plan(16);

-- ========================================
-- INDEXES: core.memberships
-- ========================================
SELECT has_index('core', 'memberships', 'idx_memberships_user_id',
  'Index idx_memberships_user_id should exist');
SELECT has_index('core', 'memberships', 'idx_memberships_organization_id',
  'Index idx_memberships_organization_id should exist');
SELECT has_index('core', 'memberships', 'idx_memberships_role_id',
  'Index idx_memberships_role_id should exist');
SELECT has_index('core', 'memberships', 'idx_one_super_admin_per_org',
  'Index idx_one_super_admin_per_org should exist');

-- ========================================
-- INDEXES: core.unit_memberships
-- ========================================
SELECT has_index('core', 'unit_memberships', 'idx_unit_memberships_user_id',
  'Index idx_unit_memberships_user_id should exist');
SELECT has_index('core', 'unit_memberships', 'idx_unit_memberships_unit_id',
  'Index idx_unit_memberships_unit_id should exist');
SELECT has_index('core', 'unit_memberships', 'idx_unit_memberships_role_id',
  'Index idx_unit_memberships_role_id should exist');

-- ========================================
-- INDEXES: core.units
-- ========================================
SELECT has_index('core', 'units', 'idx_units_organization_id',
  'Index idx_units_organization_id should exist');

-- ========================================
-- INDEXES: core.audit_logs
-- ========================================
SELECT has_index('core', 'audit_logs', 'idx_audit_logs_actor_id',
  'Index idx_audit_logs_actor_id should exist');
SELECT has_index('core', 'audit_logs', 'idx_audit_logs_organization_id',
  'Index idx_audit_logs_organization_id should exist');
SELECT has_index('core', 'audit_logs', 'idx_audit_logs_target_table',
  'Index idx_audit_logs_target_table should exist');
SELECT has_index('core', 'audit_logs', 'idx_audit_logs_metadata',
  'Index idx_audit_logs_metadata should exist');

-- ========================================
-- INDEXES: platform.billing_subscriptions
-- ========================================
SELECT has_index('platform', 'billing_subscriptions', 'idx_billing_subscriptions_organization_id',
  'Index idx_billing_subscriptions_organization_id should exist');
SELECT has_index('platform', 'billing_subscriptions', 'idx_billing_subscriptions_status',
  'Index idx_billing_subscriptions_status should exist');

-- ========================================
-- INDEXES: platform.tenant_secrets
-- ========================================
SELECT has_index('platform', 'tenant_secrets', 'idx_tenant_secrets_organization_id',
  'Index idx_tenant_secrets_organization_id should exist');
SELECT has_index('platform', 'tenant_secrets', 'idx_tenant_secrets_user_id',
  'Index idx_tenant_secrets_user_id should exist');

SELECT * FROM finish();

ROLLBACK;
