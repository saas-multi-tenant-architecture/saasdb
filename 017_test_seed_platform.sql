-- 017_test_seed_platform.sql
-- Purpose: Seed platform-specific test data relating to the core seed

\set tenant_admin_id '00000000-0000-0000-0000-00000000A001'
\set tenant_user_id  '00000000-0000-0000-0000-00000000A002'
\set other_admin_id  '00000000-0000-0000-0000-00000000A003'
\set platform_admin_id '00000000-0000-0000-0000-00000000F001'

-- Platform roles
INSERT INTO platform.platform_roles (name, description, priority)
VALUES
  ('admin', 'Full platform access', 1),
  ('support', 'Support staff', 2)
ON CONFLICT (name) DO NOTHING;

-- Platform admin user
INSERT INTO platform.platform_users (id, supabase_user_id, email, role_id)
VALUES (
  :'platform_admin_id',
  :'platform_admin_id',
  'platform@saas.com',
  (SELECT id FROM platform.platform_roles WHERE name = 'admin')
)
ON CONFLICT (id) DO NOTHING;

-- Register core organization in platform layer
INSERT INTO platform.platform_organizations (id, label)
VALUES ('10000000-0000-0000-0000-000000000001', 'Acme Corp')
ON CONFLICT (id) DO NOTHING;

INSERT INTO platform.platform_organizations (id, label)
VALUES ('10000000-0000-0000-0000-000000000002', 'Beta LLC')
ON CONFLICT (id) DO NOTHING;
