-- 03_bella_italia.sql
-- Purpose: Create Bella Italia Restaurant Group organization with units and memberships
-- Uses SECURITY DEFINER helper functions to bypass RLS
--
-- Organization: Bella Italia Restaurant Group
-- Units (Locations):
--   - Downtown
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
-- FIXED IDs (deterministic for testing)
-- ========================================
-- Organization ID: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
-- Unit IDs:
--   Downtown: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01
--   Airport:  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02
--   Mall:     bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03
-- Role IDs:
--   super_admin: 00000000-0000-0000-0000-000000000001
--   manager:     00000000-0000-0000-0000-000000000002
--   team:        00000000-0000-0000-0000-000000000003

-- ========================================
-- CREATE ORGANIZATION
-- ========================================
SELECT test_helpers.seed_organization(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Bella Italia Restaurant Group',
  'Fine Italian dining across multiple locations',
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- ========================================
-- CREATE UNITS (LOCATIONS)
-- ========================================
SELECT test_helpers.seed_unit(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Downtown',
  'Downtown flagship location',
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

SELECT test_helpers.seed_unit(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Airport Location',
  'Quick-service location at the airport terminal',
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

SELECT test_helpers.seed_unit(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Mall Location',
  'Family-friendly location in the shopping mall',
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- ========================================
-- ADD ORGANIZATION MEMBERSHIPS
-- ========================================
-- Maria - super_admin (owner)
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000001'::uuid,  -- super_admin role
  true,  -- is_super_admin
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Carlos - manager role at org level
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000002'::uuid,  -- manager role
  false,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Sofia - manager role at org level
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('sofia@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000002'::uuid,  -- manager role
  false,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Alex - team role at org level
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('alex@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  false,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Jordan - team role at org level
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('jordan@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  false,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Sam - team role at org level
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('sam@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  false,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Taylor - team role at org level (no unit assignments)
SELECT test_helpers.seed_membership(
  test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  false,
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- ========================================
-- ADD UNIT MEMBERSHIPS
-- ========================================
-- Carlos: Manager at Downtown and Airport
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,  -- Downtown
  '00000000-0000-0000-0000-000000000002'::uuid,  -- manager role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('carlos@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid,  -- Airport
  '00000000-0000-0000-0000-000000000002'::uuid,  -- manager role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Sofia: Manager at Downtown only
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('sofia@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,  -- Downtown
  '00000000-0000-0000-0000-000000000002'::uuid,  -- manager role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Alex: Team at Downtown, Manager at Mall
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('alex@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,  -- Downtown
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('alex@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid,  -- Mall
  '00000000-0000-0000-0000-000000000002'::uuid,  -- manager role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Jordan: Team at Airport and Mall
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('jordan@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid,  -- Airport
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('jordan@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb03'::uuid,  -- Mall
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Sam: Team at Downtown only
SELECT test_helpers.seed_unit_membership(
  test_helpers.get_test_user_id('sam@test.bellaitalia.com'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,  -- Downtown
  '00000000-0000-0000-0000-000000000003'::uuid,  -- team role
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

-- Taylor: No unit memberships (org member only)

-- ========================================
-- LOG AUDIT ENTRY
-- ========================================
SELECT test_helpers.seed_audit_log(
  test_helpers.get_test_user_id('maria@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'core.organizations',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'insert',
  'Created Bella Italia Restaurant Group'
);

-- ========================================
-- SUMMARY
-- ========================================
-- Organization: Bella Italia Restaurant Group
--
-- Units:
--   Downtown
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
