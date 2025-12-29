-- 01_roles.sql
-- Purpose: Seed core.roles with standard roles for testing
--
-- Role Definitions:
-- - super_admin: Organization owner (has is_super_admin flag in memberships)
-- - manager: Location/unit manager with full access to assigned units
-- - team: Team member with limited access to assigned units

-- ========================================
-- FIXED UUIDs FOR ROLES
-- ========================================
-- Using fixed UUIDs allows tests to reference roles by ID consistently

-- ========================================
-- ROLE: super_admin
-- ========================================
INSERT INTO core.roles (id, name, description, casl_rules, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'super_admin',
  'Organization owner with full administrative access',
  '[
    {"action": "manage", "subject": "all"}
  ]'::jsonb,
  now(),
  now()
) ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  casl_rules = EXCLUDED.casl_rules,
  updated_at = now();

-- ========================================
-- ROLE: manager
-- ========================================
INSERT INTO core.roles (id, name, description, casl_rules, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'manager',
  'Location manager with administrative access to assigned units',
  '[
    {"action": "read", "subject": "Organization"},
    {"action": "manage", "subject": "Unit"},
    {"action": "manage", "subject": "UnitMember"},
    {"action": "read", "subject": "AuditLog"},
    {"action": "manage", "subject": "Schedule"},
    {"action": "manage", "subject": "Inventory"}
  ]'::jsonb,
  now(),
  now()
) ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  casl_rules = EXCLUDED.casl_rules,
  updated_at = now();

-- ========================================
-- ROLE: team
-- ========================================
INSERT INTO core.roles (id, name, description, casl_rules, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000003',
  'team',
  'Team member with read access and limited write access',
  '[
    {"action": "read", "subject": "Organization"},
    {"action": "read", "subject": "Unit"},
    {"action": "read", "subject": "Schedule"},
    {"action": "update", "subject": "Schedule", "conditions": {"assignee_id": "${user.id}"}},
    {"action": "read", "subject": "Inventory"}
  ]'::jsonb,
  now(),
  now()
) ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  casl_rules = EXCLUDED.casl_rules,
  updated_at = now();

-- ========================================
-- CONSTANTS FOR TEST REFERENCE
-- ========================================
-- These can be used in tests to reference role IDs
DO $$
BEGIN
  -- Store role IDs in a temporary config for easy access in tests
  PERFORM set_config('test.role_super_admin', '00000000-0000-0000-0000-000000000001', false);
  PERFORM set_config('test.role_manager', '00000000-0000-0000-0000-000000000002', false);
  PERFORM set_config('test.role_team', '00000000-0000-0000-0000-000000000003', false);
END $$;

-- ========================================
-- NOTES
-- ========================================
-- CASL rules are stored as JSONB but enforced at the application layer
-- The SMTA database layer only uses RLS for membership/super_admin checks
-- These CASL rules serve as documentation and are passed to the frontend
