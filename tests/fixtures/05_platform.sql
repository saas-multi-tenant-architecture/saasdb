-- 05_platform.sql
-- Purpose: Create platform test data (platform roles, users, settings)

-- ========================================
-- PLATFORM ROLES (seeded for testing)
-- ========================================
-- Note: In production these would be seeded separately
INSERT INTO platform.platform_roles (id, name, description, casl_rules, created_by, updated_by) VALUES
  -- Platform Super Admin - full access
  ('10000000-0000-0000-0000-000000000001', 'platform_super_admin', 'Full platform administration access',
   '[{"action": "manage", "subject": "all"}]',
   NULL, NULL),

  -- Platform Admin - administrative access
  ('10000000-0000-0000-0000-000000000002', 'platform_admin', 'Platform administration',
   '[{"action": ["read", "create", "update"], "subject": "Organization"}, {"action": ["read", "create", "update"], "subject": "User"}, {"action": "read", "subject": "AuditLog"}]',
   NULL, NULL),

  -- Platform Viewer - read-only access
  ('10000000-0000-0000-0000-000000000003', 'platform_viewer', 'Read-only platform access',
   '[{"action": "read", "subject": "Organization"}, {"action": "read", "subject": "User"}]',
   NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- ========================================
-- PLATFORM USERS (admin users)
-- ========================================
-- Platform Super Admin
INSERT INTO platform.platform_users (id, supabase_user_id, email, role_id, created_by, updated_by) VALUES
  ('20000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111101', 'maria@bellaitalia.com',
   '10000000-0000-0000-0000-000000000001', -- platform_super_admin
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (id) DO NOTHING;

-- Platform Viewer
INSERT INTO platform.platform_users (id, supabase_user_id, email, role_id, created_by, updated_by) VALUES
  ('20000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111102', 'carlos@bellaitalia.com',
   '10000000-0000-0000-0000-000000000003', -- platform_viewer
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (id) DO NOTHING;

-- ========================================
-- PLATFORM SETTINGS (sample settings)
-- ========================================
INSERT INTO platform.platform_settings (key, value, created_by, updated_by) VALUES
  ('maintenance_mode', 'false', '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101'),
  ('max_organizations', '100', '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101'),
  ('signup_enabled', 'true', '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (key) DO NOTHING;

-- ========================================
-- PLATFORM FEATURE FLAGS (sample flags)
-- ========================================
INSERT INTO platform.platform_feature_flags (id, key, value, is_active, organization_id, created_by, updated_by) VALUES
  -- Global feature flag (no org)
  ('30000000-0000-0000-0000-000000000001', 'dark_mode', '{"enabled": true}', true, NULL,
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101'),
  -- Bella Italia specific flag
  ('30000000-0000-0000-0000-000000000002', 'beta_features', '{"dashboard_v2": true}', true,
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101'),
  -- Inactive flag
  ('30000000-0000-0000-0000-000000000003', 'experimental', '{}', false, NULL,
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (id) DO NOTHING;

-- ========================================
-- BILLING DATA (sample data)
-- ========================================
-- Billing customer for Bella Italia
INSERT INTO platform.billing_customers (id, organization_id, created_by, updated_by) VALUES
  ('40000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (id) DO NOTHING;

-- Subscription product
INSERT INTO platform.subscription_products (id, name, description, billing_interval, amount, created_by, updated_by) VALUES
  ('50000000-0000-0000-0000-000000000001', 'Professional', 'Professional tier with all features', 'monthly', 9900,
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101'),
  ('50000000-0000-0000-0000-000000000002', 'Enterprise', 'Enterprise tier with priority support', 'yearly', 99900,
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (id) DO NOTHING;

-- Billing subscription
INSERT INTO platform.billing_subscriptions (id, organization_id, product_id, status, created_by, updated_by) VALUES
  ('60000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '50000000-0000-0000-0000-000000000001', 'active',
   '11111111-1111-1111-1111-111111111101', '11111111-1111-1111-1111-111111111101')
ON CONFLICT (id) DO NOTHING;
