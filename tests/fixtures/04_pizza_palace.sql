-- 04_pizza_palace.sql
-- Purpose: Create Pizza Palace organization for cross-org isolation testing
-- Uses SECURITY DEFINER helper functions to bypass RLS
--
-- Organization: Pizza Palace
-- Units (Locations):
--   - Main Street Location
--
-- Membership Structure:
--   Luigi (super_admin) -> Org owner
--   Giuseppe (team) -> Main Street Team

-- ========================================
-- FIXED IDs (deterministic for testing)
-- ========================================
-- Organization ID: cccccccc-cccc-cccc-cccc-cccccccccccc
-- Unit IDs:
--   Main Street: dddddddd-dddd-dddd-dddd-dddddddddd01
-- Role IDs:
--   super_admin: 00000000-0000-0000-0000-000000000001
--   team:        00000000-0000-0000-0000-000000000003

-- ========================================
-- CREATE ORGANIZATION
-- ========================================
SELECT test_helpers.seed_organization(
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  'Pizza Palace',
  'Quick and delicious pizza delivery',
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
);

-- ========================================
-- CREATE UNITS (LOCATIONS)
-- ========================================
SELECT test_helpers.seed_unit(
  'dddddddd-dddd-dddd-dddd-dddddddddd01'::uuid,
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  'Main Street Location',
  'Original Pizza Palace location',
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
);

-- ========================================
-- ADD ORGANIZATION MEMBERSHIPS
-- ========================================
-- Luigi - super_admin (owner)
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid,  -- super_admin role
  true,  -- is_super_admin
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
);

-- Giuseppe - team member
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('giuseppe@test.pizzapalace.com'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  false,
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
);

-- ========================================
-- ADD UNIT MEMBERSHIPS
-- ========================================
-- Giuseppe: Team at Main Street
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('giuseppe@test.pizzapalace.com'),
  'dddddddd-dddd-dddd-dddd-dddddddddd01'::uuid,  -- Main Street
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com')
);

-- ========================================
-- LOG AUDIT ENTRY
-- ========================================
SELECT test_helpers.seed_audit_log(
  test_helpers.get_test_user_id('luigi@test.pizzapalace.com'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  'core.organizations',
  'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
  'insert',
  'Created Pizza Palace'
);

-- ========================================
-- SUMMARY
-- ========================================
-- Organization: Pizza Palace
--
-- Units:
--   Main Street Location
--
-- Memberships:
--   Luigi    -> super_admin (org owner)
--   Giuseppe -> team @ Main Street
--
-- This organization is used to test:
-- - Cross-organization isolation (Bella Italia users can't see Pizza Palace)
-- - Separate super_admin contexts
-- - Independent audit logs
