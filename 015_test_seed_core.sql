-- 015_test_seed_core.sql
-- Purpose: Seed test data for one organization, unit, platform admin, and two users

-- ========================================
-- UUID Variables (update these after Supabase user signup)
-- ========================================
\set tenant_admin_id '00000000-0000-0000-0000-00000000A001'
\set tenant_user_id  '00000000-0000-0000-0000-00000000A002'
\set other_admin_id  '00000000-0000-0000-0000-00000000A003'
\set platform_admin_id '00000000-0000-0000-0000-00000000F001'

-- ========================================
-- Organization and Metadata
-- ========================================
INSERT INTO core.organizations (id, name, created_by)
VALUES ('10000000-0000-0000-0000-000000000001', 'Acme Corp', :'tenant_admin_id');

INSERT INTO core.organization_meta (id, address, logo_url)
VALUES ('10000000-0000-0000-0000-000000000001', '123 Main St', NULL);

-- Second organization
INSERT INTO core.organizations (id, name, created_by)
VALUES ('10000000-0000-0000-0000-000000000002', 'Beta LLC', :'other_admin_id');

INSERT INTO core.organization_meta (id, address, logo_url)
VALUES ('10000000-0000-0000-0000-000000000002', '456 Beta Rd', NULL);

-- ========================================
-- Users
-- ========================================
INSERT INTO core.users_meta (id, email, first_name, last_name)
VALUES
  (:'tenant_admin_id', 'admin@acme.com', 'Alice', 'Admin'),
  (:'tenant_user_id',  'user@acme.com',  'Bob', 'User'),
  (:'other_admin_id', 'beta@acme.com', 'Betty', 'Beta');

-- ========================================
-- Memberships
-- ========================================
INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
VALUES
  (:'tenant_admin_id', '10000000-0000-0000-0000-000000000001', (SELECT id FROM core.roles WHERE name = 'admin'), :'tenant_admin_id'),
  (:'tenant_user_id',  '10000000-0000-0000-0000-000000000001', (SELECT id FROM core.roles WHERE name = 'user'),  :'tenant_admin_id'),
  (:'other_admin_id', '10000000-0000-0000-0000-000000000002', (SELECT id FROM core.roles WHERE name = 'admin'), :'other_admin_id');

-- ========================================
-- Unit and Unit Metadata
-- ========================================
INSERT INTO core.units (id, organization_id, name, created_by)
VALUES ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Acme East', :'tenant_admin_id');

INSERT INTO core.unit_meta (id, location)
VALUES ('20000000-0000-0000-0000-000000000001', 'New York');

-- Second unit for Beta organization
INSERT INTO core.units (id, organization_id, name, created_by)
VALUES ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Beta West', :'other_admin_id');

INSERT INTO core.unit_meta (id, location)
VALUES ('20000000-0000-0000-0000-000000000002', 'San Francisco');

-- ========================================
-- Unit Memberships
-- ========================================
INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
VALUES
  (:'tenant_admin_id', '20000000-0000-0000-0000-000000000001', (SELECT id FROM core.roles WHERE name = 'manager'), :'tenant_admin_id');

INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
VALUES
  (:'other_admin_id', '20000000-0000-0000-0000-000000000002', (SELECT id FROM core.roles WHERE name = 'manager'), :'other_admin_id');

-- ========================================
-- Platform User
-- ========================================
INSERT INTO platform.platform_users (id, email, role_id)
VALUES (
  :'platform_admin_id', 'platform@saas.com',
  (SELECT id FROM platform.platform_roles WHERE name = 'admin')
);
