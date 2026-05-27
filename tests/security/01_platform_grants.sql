-- 01_platform_grants.sql
-- Purpose: Verify authenticated has no direct privileges on platform.* tables
-- All platform access must flow through SECURITY DEFINER functions

BEGIN;

SELECT plan(14);

-- authenticated should NOT have USAGE on platform schema
SELECT ok(
  NOT has_schema_privilege('authenticated', 'platform', 'USAGE'),
  'authenticated must NOT have USAGE on schema platform'
);

-- authenticated should NOT have SELECT on any platform table
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_users', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_users'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_roles', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_roles'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_organizations', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_organizations'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_action_logs', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_action_logs'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_settings', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_settings'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_subscription_overrides', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_subscription_overrides'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_feature_flags', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_feature_flags'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_system_events', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_system_events'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.tenant_secrets', 'SELECT'),
  'authenticated must NOT have SELECT on platform.tenant_secrets'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.billing_customers', 'SELECT'),
  'authenticated must NOT have SELECT on platform.billing_customers'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.billing_subscriptions', 'SELECT'),
  'authenticated must NOT have SELECT on platform.billing_subscriptions'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.subscription_products', 'SELECT'),
  'authenticated must NOT have SELECT on platform.subscription_products'
);

-- Functions still callable (sanity: the function-based access path remains)
SELECT ok(
  has_function_privilege('authenticated', 'public.list_subscription_products()', 'EXECUTE'),
  'authenticated must still be able to EXECUTE public.list_subscription_products'
);

SELECT * FROM finish();
ROLLBACK;
