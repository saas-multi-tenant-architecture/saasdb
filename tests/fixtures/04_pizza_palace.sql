-- 04_pizza_palace.sql
-- Purpose: Create Pizza Palace organization for cross-org isolation testing
--
-- Organization: Pizza Palace
-- Units (Locations):
--   - Main Street Location
--
-- Membership Structure:
--   Luigi (super_admin) -> Org owner
--   Giuseppe (team) -> Main Street Team

-- ========================================
-- CREATE PIZZA PALACE ORGANIZATION
-- ========================================
DO $$
DECLARE
  -- Users
  v_luigi UUID := current_setting('test.user_luigi')::UUID;
  v_giuseppe UUID := current_setting('test.user_giuseppe')::UUID;

  -- Roles
  v_role_super_admin UUID := current_setting('test.role_super_admin')::UUID;
  v_role_team UUID := current_setting('test.role_team')::UUID;

  -- Organization and Units
  v_org_id UUID;
  v_mainstreet_id UUID;
BEGIN
  -- ========================================
  -- CREATE ORGANIZATION AS LUIGI
  -- ========================================
  PERFORM test_helpers.set_auth_user(v_luigi);

  -- Create the organization
  INSERT INTO core.organizations (id, name, description, created_by)
  VALUES (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'Pizza Palace',
    'Quick and delicious pizza delivery',
    v_luigi
  )
  RETURNING id INTO v_org_id;

  -- Create Luigi's super_admin membership
  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by)
  VALUES (v_luigi, v_org_id, v_role_super_admin, true, v_luigi);

  -- Store org ID for tests
  PERFORM set_config('test.org_pizza_palace', v_org_id::text, false);

  -- ========================================
  -- CREATE UNITS (LOCATIONS)
  -- ========================================

  -- Main Street Location
  INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
  VALUES (
    'dddddddd-dddd-dddd-dddd-dddddddddd01',
    v_org_id,
    'Main Street Location',
    'Original Pizza Palace location',
    v_luigi,
    v_luigi
  )
  RETURNING id INTO v_mainstreet_id;

  -- Store unit ID for tests
  PERFORM set_config('test.unit_mainstreet', v_mainstreet_id::text, false);

  -- ========================================
  -- ADD ORGANIZATION MEMBERS
  -- ========================================

  -- Giuseppe - team member
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_giuseppe, v_org_id, v_role_team, v_luigi);

  -- ========================================
  -- ADD UNIT MEMBERSHIPS
  -- ========================================

  -- Giuseppe: Team at Main Street
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_giuseppe, v_mainstreet_id, v_role_team, v_luigi);

  -- ========================================
  -- LOG AUDIT ENTRIES
  -- ========================================
  INSERT INTO core.audit_logs (actor_id, organization_id, target_table, target_id, action, summary)
  VALUES (v_luigi, v_org_id, 'core.organizations', v_org_id, 'insert', 'Created Pizza Palace');

  -- Clear auth user
  PERFORM test_helpers.clear_auth_user();
END $$;

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
