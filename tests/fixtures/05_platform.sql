-- 05_platform.sql
-- Purpose: Create platform test data (platform roles, users, settings)
-- Uses SECURITY DEFINER helper functions to bypass RLS

-- ========================================
-- PLATFORM ROLES (seeded for testing)
-- ========================================
-- Platform Super Admin - full access
SELECT test_helpers.seed_platform_role(
  '10000000-0000-0000-0000-000000000001'::uuid,
  'super_admin',
  'Full platform administration access',
  '[{"action": "manage", "subject": "all"}]'::jsonb
);

-- Platform Admin - administrative access
SELECT test_helpers.seed_platform_role(
  '10000000-0000-0000-0000-000000000002'::uuid,
  'platform_admin',
  'Platform administration',
  '[{"action": ["read", "create", "update"], "subject": "Organization"}, {"action": ["read", "create", "update"], "subject": "User"}, {"action": "read", "subject": "AuditLog"}]'::jsonb
);

-- Platform Viewer - read-only access
SELECT test_helpers.seed_platform_role(
  '10000000-0000-0000-0000-000000000003'::uuid,
  'platform_viewer',
  'Read-only platform access',
  '[{"action": "read", "subject": "Organization"}, {"action": "read", "subject": "User"}]'::jsonb
);

-- ========================================
-- PLATFORM USERS (SaaS operator staff)
-- ========================================
-- Note: These users must exist in auth.users first (created in 02_test_users.sql)
-- Platform users are employees of "PizzaTech SaaS" - the company that operates
-- the pizza restaurant management platform. They are NOT tenant users.

-- Platform Super Admin (Sarah - CTO)
SELECT test_helpers.seed_platform_user(
  '20000000-0000-0000-0000-000000000001'::uuid,
  test_helpers.get_test_user_id('sarah@pizzatech-saas.com'),  -- user_id
  'sarah@pizzatech-saas.com',
  '10000000-0000-0000-0000-000000000001'::uuid   -- super_admin role
);

-- Platform Viewer (Mike - Support Staff)
SELECT test_helpers.seed_platform_user(
  '20000000-0000-0000-0000-000000000002'::uuid,
  test_helpers.get_test_user_id('mike@pizzatech-saas.com'),  -- user_id
  'mike@pizzatech-saas.com',
  '10000000-0000-0000-0000-000000000003'::uuid   -- platform_viewer role
);

-- ========================================
-- PLATFORM SETTINGS (sample settings)
-- ========================================
-- Note: value is JSONB type
SELECT test_helpers.seed_platform_setting('maintenance_mode', 'false'::jsonb, 'Enable/disable maintenance mode');
SELECT test_helpers.seed_platform_setting('max_organizations', '100'::jsonb, 'Maximum number of organizations allowed');
SELECT test_helpers.seed_platform_setting('signup_enabled', 'true'::jsonb, 'Enable/disable new signups');

-- ========================================
-- PLATFORM ORGANIZATIONS (required for feature flags FK)
-- ========================================
-- Create platform organization entry for Bella Italia
SELECT test_helpers.seed_platform_organization(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Bella Italia',
  'Test restaurant organization'
);

-- ========================================
-- PLATFORM FEATURE FLAGS (sample flags)
-- ========================================
-- Global feature flag (no org)
SELECT test_helpers.seed_feature_flag(
  '30000000-0000-0000-0000-000000000001'::uuid,
  'dark_mode',
  '{"enabled": true}'::jsonb,
  true,
  NULL,
  'Enable dark mode UI theme'
);

-- Bella Italia specific flag
SELECT test_helpers.seed_feature_flag(
  '30000000-0000-0000-0000-000000000002'::uuid,
  'beta_features',
  '{"dashboard_v2": true}'::jsonb,
  true,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Beta features for specific organization'
);

-- Inactive flag
SELECT test_helpers.seed_feature_flag(
  '30000000-0000-0000-0000-000000000003'::uuid,
  'experimental',
  '{}'::jsonb,
  false,
  NULL,
  'Experimental features (inactive)'
);

-- ========================================
-- BILLING DATA (sample data)
-- ========================================
-- Billing customer for Bella Italia
SELECT test_helpers.seed_billing_customer(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'cus_test_bellaitalia_001',
  'billing@bellaitalia.com'
);

-- Subscription products
SELECT test_helpers.seed_subscription_product(
  '50000000-0000-0000-0000-000000000001'::uuid,
  'price_professional_monthly',
  'Professional',
  'Professional tier with all features',
  'monthly',
  9900
);

SELECT test_helpers.seed_subscription_product(
  '50000000-0000-0000-0000-000000000002'::uuid,
  'price_enterprise_yearly',
  'Enterprise',
  'Enterprise tier with priority support',
  'yearly',
  99900
);

-- Billing subscription for Bella Italia
SELECT test_helpers.seed_billing_subscription(
  '60000000-0000-0000-0000-000000000001'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'sub_test_bellaitalia_001',
  'professional',
  'active'
);
