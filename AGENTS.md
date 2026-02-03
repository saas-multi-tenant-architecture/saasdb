# AGENTS.md - Developer Guide for AI Coding Agents

## Project Overview

**SMTA (SaaS Multi-Tenant Architecture)** is a PostgreSQL/Supabase-based multi-tenant SaaS backend framework. It provides tenant isolation, role-based access control, audit logging, soft deletion, and billing integration.

**Key Technologies:**
- PostgreSQL with plpgsql functions
- Supabase (authentication, RLS, Vault)
- CASL for isomorphic, granular authorization
- Zod v3 for type-safe validation
- pgTap for database testing

**Security Model:**
- **RLS (Row Level Security)**: Enforces tenant separation at the database level
- **CASL**: Provides granular, isomorphic role-based authorization that works across frontend and backend

---

## Build, Test, and Lint Commands

### Build
```bash
# Combine SQL files into single deployment script
npm run build
```

### Testing

**Run all tests:**
```bash
npm test
# or
./run_tests.sh
```

**Run specific test category:**
```bash
# Schema tests
pg_prove -v postgresql://postgres:postgres@localhost:54322/postgres tests/schema/*.sql

# RLS tests
pg_prove -v postgresql://postgres:postgres@localhost:54322/postgres tests/rls/*.sql

# Platform tests
pg_prove -v postgresql://postgres:postgres@localhost:54322/postgres tests/platform/*.sql
```

**Run a single test file:**
```bash
pg_prove -v postgresql://postgres:postgres@localhost:54322/postgres \
  tests/rls/01_organizations_rls.sql
```

**Test execution order:**
1. `tests/fixtures/` - Test data and helpers (loaded once)
2. `tests/schema/` - Schema validation
3. `tests/membership/` - Role and membership logic
4. `tests/triggers/` - Trigger functionality
5. `tests/platform/` - Platform admin functions
6. `tests/functions/` - Public RPC functions
7. `tests/rls/` - Row Level Security policies
8. `tests/edge_cases/` - Complex scenarios

---

## Code Style Guidelines

### SQL Formatting

**Keywords and Types:** UPPERCASE
```sql
SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP
UUID, TEXT, BOOLEAN, TIMESTAMPTZ, JSONB, INTEGER
LANGUAGE plpgsql, SECURITY INVOKER, SECURITY DEFINER
```

**Identifiers:** lowercase with underscores
```sql
-- Schemas
core, platform, public, auth, utils, app

-- Tables
organizations, users_meta, audit_logs, unit_memberships

-- Columns
user_id, organization_id, is_deleted, created_at
```

**Indentation:** 2 spaces, consistent alignment

**Spacing:** 
- Space after commas
- Spaces around operators (`=`, `<>`, `AND`, `OR`)
- No space between function name and parenthesis: `auth.uid()`, `now()`

### Naming Conventions

**Functions:**
- Public RPC: `verb_noun` pattern
  - `list_my_organizations()`, `create_organization()`, `update_organization()`, `delete_unit()`
- RLS helpers: Boolean check with `is_` or `has_` prefix
  - `is_super_admin()`, `is_org_member()`, `has_org_role()`
- Platform: Descriptive action pattern
  - `create_platform_user()`, `ensure_platform_admin()`
- Triggers: `handle_` prefix or action description
  - `handle_new_organization()`, `protect_super_admin()`

**Parameters:** Prefix with `p_`
```sql
p_org_id, p_user_id, p_name, p_email, p_role_id
```

**Variables:** Prefix with `v_`
```sql
v_org_id, v_user_id, v_token, v_count
```

**Columns:**
- Foreign keys: `{entity}_id` (e.g., `user_id`, `organization_id`)
- Booleans: `is_{state}` (e.g., `is_deleted`, `is_super_admin`)
- Timestamps: `{action}_at` (e.g., `created_at`, `updated_at`, `deleted_at`)
- Actors: `{action}_by` (e.g., `created_by`, `deleted_by`)

**Tables:**
- Use plural nouns: `organizations`, `users`, `memberships`
- Platform tables: `platform_` prefix (e.g., `platform_users`)

### Type Usage

**Always use:**
- `TIMESTAMPTZ` (never plain TIMESTAMP)
- `UUID` for all IDs
- `TEXT` (never VARCHAR)
- `JSONB` (never JSON)
- `BOOLEAN` for flags

**Examples:**
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
name TEXT NOT NULL,
metadata JSONB DEFAULT '{}'::jsonb,
is_deleted BOOLEAN DEFAULT false,
created_at TIMESTAMPTZ DEFAULT NOW()
```

### Standard Audit Fields

Include on all domain tables:
```sql
created_by UUID,
updated_by UUID,
is_deleted BOOLEAN DEFAULT false,
deleted_at TIMESTAMPTZ,
deleted_by UUID,
created_at TIMESTAMPTZ DEFAULT NOW(),
updated_at TIMESTAMPTZ DEFAULT NOW()
```

### Comments

**File headers:**
```sql
-- filename.sql
-- Purpose: Brief description of file contents
```

**Section separators:**
```sql
-- ========================================
-- SECTION NAME
-- ========================================
```

**Inline comments:**
- Explain business logic and security decisions
- Clarify complex queries
- Document edge cases
- Always explain SECURITY DEFINER usage

---

## Function Patterns

### Security Context

**SECURITY INVOKER** (runs with caller's permissions):
- Use for public RPC functions where RLS should apply
- Pattern: `$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;`

**SECURITY DEFINER** (runs with owner's permissions):
- Use for core helpers, platform functions, audit logging, triggers
- Always comment why SECURITY DEFINER is needed
- Pattern: `$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = {schema};`

### Function Template

```sql
CREATE OR REPLACE FUNCTION schema.function_name(
  p_param1 TYPE,
  p_param2 TYPE DEFAULT value
)
RETURNS return_type AS $$
DECLARE
  v_var1 TYPE;
  v_var2 TYPE;
BEGIN
  -- Validate inputs
  -- Check authorization
  -- Perform operations
  -- Log audit trail
  -- Return result
  RETURN value;
END;
$$ LANGUAGE plpgsql SECURITY [INVOKER|DEFINER] SET search_path = schema;
```

### Error Handling

Use `RAISE EXCEPTION` with descriptive messages:
```sql
RAISE EXCEPTION 'Organization name is required';
RAISE EXCEPTION 'Organization not found';
RAISE EXCEPTION 'Only a super_admin can update the organization';
RAISE EXCEPTION 'User % not found', p_user_id;
```

### Authorization Patterns

**Guard functions (platform):**
```sql
PERFORM platform.ensure_platform_admin();
```

**Inline checks (tenant):**
```sql
IF NOT core.is_super_admin(p_org_id) THEN
  RAISE EXCEPTION 'Only a super_admin can update the organization';
END IF;
```

**Privacy-preserving checks:**
```sql
-- Don't leak whether org exists to non-members
IF NOT core.is_org_member(p_id) THEN
  RAISE EXCEPTION 'Organization not found';
END IF;
```

### Audit Logging

Always log mutations:
```sql
PERFORM core.log_audit(
  'insert',
  'core.organizations',
  v_org_id,
  'create_organization',
  jsonb_build_object('name', p_name, 'description', p_description)
);
```

---

## Schema Organization

### Schema Boundaries

- `core`: Identity, access control, memberships, roles, audit logs
- `platform`: SaaS-wide admin layer (service role only)
- `app`: Tenant-specific application tables (extend for your SaaS)
- `utils`: Shared triggers and helper functions
- `public`: SQL functions only (RPC endpoints for clients)

### Access Model

- **No direct table access** from clients
- All client operations via `public` schema RPC functions
- RLS enforces tenant isolation on underlying tables
- CASL provides granular role-based permissions
- Platform schema locked down with `USING (false)` policies

---

## Common Patterns

### Soft Delete
```sql
UPDATE schema.table
SET is_deleted = true,
    deleted_at = NOW(),
    deleted_by = auth.uid()
WHERE id = p_id
  AND is_deleted = false;
```

### Query Filtering
Always exclude soft-deleted records:
```sql
WHERE is_deleted = false
```

### Timestamp Management
```sql
-- Current time
NOW()

-- Intervals
expires_at := NOW() + INTERVAL '7 days'
WHERE expires_at > NOW()
```

### Actor Tracking
```sql
-- On insert
INSERT INTO schema.table (created_by, updated_by)
VALUES (auth.uid(), auth.uid());

-- On update
UPDATE schema.table
SET updated_by = auth.uid(),
    updated_at = NOW()
WHERE ...
```

### PERFORM vs SELECT
```sql
-- Use PERFORM when result not needed
PERFORM core.log_audit(...);

-- Use SELECT INTO when capturing result
SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;
```

---

## Testing Guidelines

### Test File Template
```sql
-- test_name.sql
-- Purpose: Description of what this validates

BEGIN;

SELECT plan(5); -- Number of test assertions

-- ========================================
-- TEST: Description
-- ========================================
SELECT ok(
  condition_to_test,
  'Human-readable description'
);

SELECT * FROM finish();

ROLLBACK;
```

### Test Helpers
```sql
-- Simulate authentication
SELECT test_helpers.set_auth_user('user-uuid-here');

-- Clear authentication
SELECT test_helpers.clear_auth_user();

-- Set service role
SELECT test_helpers.set_service_role();
```

### Important Testing Rules
- Each test file must begin with `BEGIN;` and end with `ROLLBACK;`
- Do NOT load fixtures in individual test files
- Use `SELECT plan(N)` with exact assertion count
- Always use `SELECT * FROM finish()` before `ROLLBACK;`

---

## Best Practices

1. **Avoid abbreviations**: Use `organization_id`, not `org_id` in the README (though both are acceptable)
2. **No PostgreSQL enums**: Use lookup tables instead
3. **Fully qualify joins**: `core.organizations o` for clarity
4. **Privacy-first errors**: Don't leak existence of resources to unauthorized users
5. **Always log mutations**: Use `core.log_audit()` for all create/update/delete
6. **Belt and suspenders security**: Validate in functions AND enforce with RLS
7. **Use CASL for granular authorization**: RLS handles tenant separation, CASL handles role permissions
8. **Never hard DELETE**: Always soft delete with audit trail
9. **Consistent search_path**: Always set in function definition
10. **Use PERFORM for void calls**: Don't use SELECT when result is discarded

---

## SQL Script Deployment Order

Refer to `sql-scripts.json` for the complete deployment order. Key sequence:
1. `sql/00_init/schemas.sql` - Create schemas
2. `sql/_utils/functions.sql` - Shared utilities
3. `sql/_platform/tables/*.sql` - Platform tables
4. `sql/_core/tables/*.sql` - Core tables
5. `sql/_core/triggers/*.sql` - Triggers
6. `sql/_core/rls/*.sql` - RLS policies and helpers
7. `sql/_core/functions/*.sql` - Core functions
8. `sql/_public/functions/*.sql` - Public RPC endpoints
9. `sql/_platform/functions/*.sql` - Platform admin functions

---

## Additional Resources

- **README.md**: Comprehensive architecture documentation
- **TESTING.md**: Detailed testing guide with pgTap setup
- **sql-scripts.json**: Canonical deployment order
- [CASL Documentation](https://casl.js.org/v6/en/guide/intro): For authorization patterns
- [pgTap Documentation](https://pgtap.org/): For database testing
- [Supabase Docs](https://supabase.com/docs): For RLS and authentication
