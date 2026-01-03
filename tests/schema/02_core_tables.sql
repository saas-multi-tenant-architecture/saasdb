-- 02_core_tables.sql
-- Purpose: Verify all core schema tables exist with correct structure

BEGIN;

SELECT plan(58);

-- ========================================
-- TABLE: core.organizations
-- ========================================
SELECT has_table('core', 'organizations', 'Table core.organizations should exist');
SELECT has_column('core', 'organizations', 'id', 'organizations.id should exist');
SELECT has_column('core', 'organizations', 'name', 'organizations.name should exist');
SELECT has_column('core', 'organizations', 'description', 'organizations.description should exist');
SELECT has_column('core', 'organizations', 'created_by', 'organizations.created_by should exist');
SELECT has_column('core', 'organizations', 'is_deleted', 'organizations.is_deleted should exist');
SELECT col_is_pk('core', 'organizations', 'id', 'organizations.id should be primary key');

-- ========================================
-- TABLE: core.organizations_meta
-- ========================================
SELECT has_table('core', 'organizations_meta', 'Table core.organizations_meta should exist');
SELECT has_column('core', 'organizations_meta', 'id', 'organizations_meta.id should exist');
SELECT has_column('core', 'organizations_meta', 'logo_file_id', 'organizations_meta.logo_file_id should exist');
SELECT has_column('core', 'organizations_meta', 'timezone', 'organizations_meta.timezone should exist');
SELECT col_is_pk('core', 'organizations_meta', 'id', 'organizations_meta.id should be primary key');

-- ========================================
-- TABLE: core.units
-- ========================================
SELECT has_table('core', 'units', 'Table core.units should exist');
SELECT has_column('core', 'units', 'id', 'units.id should exist');
SELECT has_column('core', 'units', 'organization_id', 'units.organization_id should exist');
SELECT has_column('core', 'units', 'name', 'units.name should exist');
SELECT has_column('core', 'units', 'description', 'units.description should exist');
SELECT col_is_pk('core', 'units', 'id', 'units.id should be primary key');
SELECT fk_ok('core', 'units', 'organization_id', 'core', 'organizations', 'id',
  'units.organization_id should reference organizations.id');

-- ========================================
-- TABLE: core.unit_meta
-- ========================================
SELECT has_table('core', 'unit_meta', 'Table core.unit_meta should exist');
SELECT has_column('core', 'unit_meta', 'id', 'unit_meta.id should exist');
SELECT has_column('core', 'unit_meta', 'notes', 'unit_meta.notes should exist');
SELECT col_is_pk('core', 'unit_meta', 'id', 'unit_meta.id should be primary key');

-- ========================================
-- TABLE: core.roles
-- ========================================
SELECT has_table('core', 'roles', 'Table core.roles should exist');
SELECT has_column('core', 'roles', 'id', 'roles.id should exist');
SELECT has_column('core', 'roles', 'name', 'roles.name should exist');
SELECT has_column('core', 'roles', 'description', 'roles.description should exist');
SELECT has_column('core', 'roles', 'casl_rules', 'roles.casl_rules should exist');
SELECT col_is_pk('core', 'roles', 'id', 'roles.id should be primary key');
SELECT col_is_unique('core', 'roles', 'name', 'roles.name should be unique');

-- ========================================
-- TABLE: core.memberships
-- ========================================
SELECT has_table('core', 'memberships', 'Table core.memberships should exist');
SELECT has_column('core', 'memberships', 'id', 'memberships.id should exist');
SELECT has_column('core', 'memberships', 'user_id', 'memberships.user_id should exist');
SELECT has_column('core', 'memberships', 'organization_id', 'memberships.organization_id should exist');
SELECT has_column('core', 'memberships', 'role_id', 'memberships.role_id should exist');
SELECT has_column('core', 'memberships', 'is_super_admin', 'memberships.is_super_admin should exist');
SELECT col_is_pk('core', 'memberships', 'id', 'memberships.id should be primary key');
SELECT fk_ok('core', 'memberships', 'organization_id', 'core', 'organizations', 'id',
  'memberships.organization_id should reference organizations.id');
SELECT fk_ok('core', 'memberships', 'role_id', 'core', 'roles', 'id',
  'memberships.role_id should reference roles.id');

-- ========================================
-- TABLE: core.unit_memberships
-- ========================================
SELECT has_table('core', 'unit_memberships', 'Table core.unit_memberships should exist');
SELECT has_column('core', 'unit_memberships', 'id', 'unit_memberships.id should exist');
SELECT has_column('core', 'unit_memberships', 'user_id', 'unit_memberships.user_id should exist');
SELECT has_column('core', 'unit_memberships', 'unit_id', 'unit_memberships.unit_id should exist');
SELECT has_column('core', 'unit_memberships', 'role_id', 'unit_memberships.role_id should exist');
SELECT col_is_pk('core', 'unit_memberships', 'id', 'unit_memberships.id should be primary key');
SELECT fk_ok('core', 'unit_memberships', 'unit_id', 'core', 'units', 'id',
  'unit_memberships.unit_id should reference units.id');
SELECT fk_ok('core', 'unit_memberships', 'role_id', 'core', 'roles', 'id',
  'unit_memberships.role_id should reference roles.id');

-- ========================================
-- TABLE: core.users_meta
-- ========================================
SELECT has_table('core', 'users_meta', 'Table core.users_meta should exist');
SELECT has_column('core', 'users_meta', 'id', 'users_meta.id should exist');
SELECT has_column('core', 'users_meta', 'first_name', 'users_meta.first_name should exist');
SELECT has_column('core', 'users_meta', 'last_name', 'users_meta.last_name should exist');
SELECT has_column('core', 'users_meta', 'email', 'users_meta.email should exist');
SELECT col_is_pk('core', 'users_meta', 'id', 'users_meta.id should be primary key');

-- ========================================
-- TABLE: core.audit_logs
-- ========================================
SELECT has_table('core', 'audit_logs', 'Table core.audit_logs should exist');
SELECT has_column('core', 'audit_logs', 'id', 'audit_logs.id should exist');
SELECT has_column('core', 'audit_logs', 'actor_id', 'audit_logs.actor_id should exist');
SELECT has_column('core', 'audit_logs', 'organization_id', 'audit_logs.organization_id should exist');
SELECT has_column('core', 'audit_logs', 'action', 'audit_logs.action should exist');

SELECT * FROM finish();

ROLLBACK;
