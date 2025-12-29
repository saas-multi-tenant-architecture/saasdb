-- 03_bella_italia.sql
-- Purpose: Create Bella Italia Restaurant Group organization with units and memberships
--
-- Organization: Bella Italia Restaurant Group
-- Units (Locations):
--   - Downtown Location
--   - Airport Location
--   - Mall Location
--
-- Membership Structure:
--   Maria (super_admin) -> Org owner, implicit access to all
--   Carlos (manager) -> Downtown Manager, Airport Manager
--   Sofia (manager) -> Downtown Manager
--   Alex (team at Downtown, manager at Mall)
--   Jordan (team) -> Airport Team, Mall Team
--   Sam (team) -> Downtown Team
--   Taylor (team) -> Org member only, no unit assignments

-- ========================================
-- HELPER: Get user and role IDs
-- ========================================
DO $$
DECLARE
  -- Users
  v_maria UUID := current_setting('test.user_maria')::UUID;
  v_carlos UUID := current_setting('test.user_carlos')::UUID;
  v_sofia UUID := current_setting('test.user_sofia')::UUID;
  v_alex UUID := current_setting('test.user_alex')::UUID;
  v_jordan UUID := current_setting('test.user_jordan')::UUID;
  v_sam UUID := current_setting('test.user_sam')::UUID;
  v_taylor UUID := current_setting('test.user_taylor')::UUID;

  -- Roles
  v_role_super_admin UUID := current_setting('test.role_super_admin')::UUID;
  v_role_manager UUID := current_setting('test.role_manager')::UUID;
  v_role_team UUID := current_setting('test.role_team')::UUID;

  -- Organization and Units
  v_org_id UUID;
  v_downtown_id UUID;
  v_airport_id UUID;
  v_mall_id UUID;
BEGIN
  -- ========================================
  -- CREATE ORGANIZATION AS MARIA
  -- ========================================
  -- Simulate Maria creating the organization
  PERFORM test_helpers.set_auth_user(v_maria);

  -- Create the organization (Maria becomes super_admin automatically)
  INSERT INTO core.organizations (id, name, description, created_by)
  VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Bella Italia Restaurant Group',
    'Fine Italian dining across multiple locations',
    v_maria
  )
  RETURNING id INTO v_org_id;

  -- Trigger creates organizations_meta and platform.platform_organizations
  -- Now manually create Maria's super_admin membership
  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by)
  VALUES (v_maria, v_org_id, v_role_super_admin, true, v_maria);

  -- Store org ID for tests
  PERFORM set_config('test.org_bella_italia', v_org_id::text, false);

  -- ========================================
  -- CREATE UNITS (LOCATIONS)
  -- ========================================

  -- Downtown Location
  INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
    v_org_id,
    'Downtown Location',
    'Flagship location in the city center',
    v_maria,
    v_maria
  )
  RETURNING id INTO v_downtown_id;

  -- Airport Location
  INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02',
    v_org_id,
    'Airport Location',
    'Quick-service location at the airport terminal',
    v_maria,
    v_maria
  )
  RETURNING id INTO v_airport_id;

  -- Mall Location
  INSERT INTO core.units (id, organization_id, name, description, created_by, updated_by)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03',
    v_org_id,
    'Mall Location',
    'Family-friendly location in the shopping mall',
    v_maria,
    v_maria
  )
  RETURNING id INTO v_mall_id;

  -- Store unit IDs for tests
  PERFORM set_config('test.unit_downtown', v_downtown_id::text, false);
  PERFORM set_config('test.unit_airport', v_airport_id::text, false);
  PERFORM set_config('test.unit_mall', v_mall_id::text, false);

  -- ========================================
  -- ADD ORGANIZATION MEMBERS
  -- ========================================

  -- Carlos - manager role at org level
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_carlos, v_org_id, v_role_manager, v_maria);

  -- Sofia - manager role at org level
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_sofia, v_org_id, v_role_manager, v_maria);

  -- Alex - team role at org level (has different roles at unit level)
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_alex, v_org_id, v_role_team, v_maria);

  -- Jordan - team role at org level
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_jordan, v_org_id, v_role_team, v_maria);

  -- Sam - team role at org level
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_sam, v_org_id, v_role_team, v_maria);

  -- Taylor - team role at org level (no unit assignments)
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_taylor, v_org_id, v_role_team, v_maria);

  -- ========================================
  -- ADD UNIT MEMBERSHIPS
  -- ========================================

  -- Carlos: Manager at Downtown and Airport
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_carlos, v_downtown_id, v_role_manager, v_maria);
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_carlos, v_airport_id, v_role_manager, v_maria);

  -- Sofia: Manager at Downtown only
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_sofia, v_downtown_id, v_role_manager, v_maria);

  -- Alex: Team at Downtown, Manager at Mall
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_alex, v_downtown_id, v_role_team, v_maria);
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_alex, v_mall_id, v_role_manager, v_maria);

  -- Jordan: Team at Airport and Mall
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_jordan, v_airport_id, v_role_team, v_maria);
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_jordan, v_mall_id, v_role_team, v_maria);

  -- Sam: Team at Downtown only
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (v_sam, v_downtown_id, v_role_team, v_maria);

  -- Taylor: No unit memberships (org member only)

  -- ========================================
  -- LOG AUDIT ENTRIES
  -- ========================================
  INSERT INTO core.audit_logs (actor_id, organization_id, target_table, target_id, action, summary)
  VALUES (v_maria, v_org_id, 'core.organizations', v_org_id, 'insert', 'Created Bella Italia Restaurant Group');

  -- Clear auth user
  PERFORM test_helpers.clear_auth_user();
END $$;

-- ========================================
-- SUMMARY
-- ========================================
-- Organization: Bella Italia Restaurant Group
--
-- Units:
--   Downtown Location
--   Airport Location
--   Mall Location
--
-- Memberships:
--   Maria    -> super_admin (org owner)
--   Carlos   -> manager @ Downtown, Airport
--   Sofia    -> manager @ Downtown
--   Alex     -> team @ Downtown, manager @ Mall
--   Jordan   -> team @ Airport, Mall
--   Sam      -> team @ Downtown
--   Taylor   -> org member only (no units)
