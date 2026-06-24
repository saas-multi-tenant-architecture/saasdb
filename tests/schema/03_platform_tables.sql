-- 03_platform_tables.sql
-- Purpose: Verify all platform schema tables exist with correct structure

BEGIN;

SELECT plan(45);

-- ========================================
-- TABLE: platform.platform_roles
-- ========================================
SELECT has_table('platform', 'platform_roles', 'Table platform.platform_roles should exist');
SELECT has_column('platform', 'platform_roles', 'id', 'platform_roles.id should exist');
SELECT has_column('platform', 'platform_roles', 'name', 'platform_roles.name should exist');
SELECT has_column('platform', 'platform_roles', 'casl_rules', 'platform_roles.casl_rules should exist');
SELECT col_is_pk('platform', 'platform_roles', 'id', 'platform_roles.id should be primary key');

-- ========================================
-- TABLE: platform.platform_users
-- ========================================
SELECT has_table('platform', 'platform_users', 'Table platform.platform_users should exist');
SELECT has_column('platform', 'platform_users', 'id', 'platform_users.id should exist');
SELECT has_column('platform', 'platform_users', 'user_id', 'platform_users.user_id should exist');
SELECT has_column('platform', 'platform_users', 'email', 'platform_users.email should exist');
SELECT has_column('platform', 'platform_users', 'role_id', 'platform_users.role_id should exist');
SELECT has_column('platform', 'platform_users', 'is_deleted', 'platform_users.is_deleted should exist');
SELECT col_is_pk('platform', 'platform_users', 'id', 'platform_users.id should be primary key');

-- ========================================
-- TABLE: platform.platform_organizations
-- ========================================
SELECT has_table('platform', 'platform_organizations', 'Table platform.platform_organizations should exist');
SELECT has_column('platform', 'platform_organizations', 'id', 'platform_organizations.id should exist');
SELECT has_column('platform', 'platform_organizations', 'label', 'platform_organizations.label should exist');

-- ========================================
-- TABLE: platform.platform_settings
-- ========================================
SELECT has_table('platform', 'platform_settings', 'Table platform.platform_settings should exist');
SELECT has_column('platform', 'platform_settings', 'key', 'platform_settings.key should exist');
SELECT has_column('platform', 'platform_settings', 'value', 'platform_settings.value should exist');
SELECT col_is_pk('platform', 'platform_settings', 'key', 'platform_settings.key should be primary key');

-- ========================================
-- TABLE: platform.platform_feature_flags
-- ========================================
SELECT has_table('platform', 'platform_feature_flags', 'Table platform.platform_feature_flags should exist');
SELECT has_column('platform', 'platform_feature_flags', 'id', 'platform_feature_flags.id should exist');
SELECT has_column('platform', 'platform_feature_flags', 'key', 'platform_feature_flags.key should exist');
SELECT has_column('platform', 'platform_feature_flags', 'value', 'platform_feature_flags.value should exist');
SELECT has_column('platform', 'platform_feature_flags', 'is_active', 'platform_feature_flags.is_active should exist');
SELECT has_column('platform', 'platform_feature_flags', 'organization_id', 'platform_feature_flags.organization_id should exist');

-- ========================================
-- TABLE: platform.platform_action_logs
-- ========================================
SELECT has_table('platform', 'platform_action_logs', 'Table platform.platform_action_logs should exist');
SELECT has_column('platform', 'platform_action_logs', 'id', 'platform_action_logs.id should exist');
SELECT has_column('platform', 'platform_action_logs', 'platform_user_id', 'platform_action_logs.platform_user_id should exist');
SELECT has_column('platform', 'platform_action_logs', 'action_type', 'platform_action_logs.action_type should exist');

-- ========================================
-- TABLE: platform.billing_customers
-- ========================================
SELECT has_table('platform', 'billing_customers', 'Table platform.billing_customers should exist');
SELECT has_column('platform', 'billing_customers', 'organization_id', 'billing_customers.organization_id should exist');
SELECT has_column('platform', 'billing_customers', 'provider_customer_id', 'billing_customers.provider_customer_id should exist');
SELECT has_column('platform', 'billing_customers', 'provider', 'billing_customers.provider should exist');
SELECT has_column('platform', 'billing_customers', 'billing_email', 'billing_customers.billing_email should exist');

-- ========================================
-- TABLE: platform.billing_subscriptions
-- ========================================
SELECT has_table('platform', 'billing_subscriptions', 'Table platform.billing_subscriptions should exist');
SELECT has_column('platform', 'billing_subscriptions', 'id', 'billing_subscriptions.id should exist');
SELECT has_column('platform', 'billing_subscriptions', 'organization_id', 'billing_subscriptions.organization_id should exist');
SELECT has_column('platform', 'billing_subscriptions', 'status', 'billing_subscriptions.status should exist');

-- ========================================
-- TABLE: platform.subscription_products
-- ========================================
SELECT has_table('platform', 'subscription_products', 'Table platform.subscription_products should exist');
SELECT has_column('platform', 'subscription_products', 'id', 'subscription_products.id should exist');
SELECT has_column('platform', 'subscription_products', 'name', 'subscription_products.name should exist');
SELECT has_column('platform', 'subscription_products', 'billing_interval', 'subscription_products.billing_interval should exist');
SELECT has_column('platform', 'subscription_products', 'amount', 'subscription_products.amount should exist');

-- ========================================
-- TABLE: platform.tenant_secrets
-- ========================================
SELECT has_table('platform', 'tenant_secrets', 'Table platform.tenant_secrets should exist');
SELECT has_column('platform', 'tenant_secrets', 'scope', 'tenant_secrets.scope should exist');

SELECT * FROM finish();

ROLLBACK;
