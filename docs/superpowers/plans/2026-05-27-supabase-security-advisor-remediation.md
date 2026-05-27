# Supabase Security Advisor Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve 39 Supabase Security Advisor warnings (24 GraphQL exposure, 14 SECURITY DEFINER execute, 1 RLS-with-no-policies) without disturbing the RLS-as-gateway design.

**Architecture:** Four targeted SQL-only changes:
1. Strip the overly broad grants in `platform/tables/grants.sql` that contradict the schema-level lockdown in `init/schemas.sql`.
2. Add a new `public/grants.sql` that revokes anon EXECUTE on six admin-only SECURITY DEFINER functions while preserving authenticated/service_role access.
3. Add an RLS SELECT policy for `core.roles` (currently RLS-enabled with no policies).
4. Add `@graphql({"expose": false})` comments to all 11 `core.*` tables so pg_graphql excludes them from the GraphQL schema — keeping every `SECURITY INVOKER` function and every RLS policy unchanged.

**Tech Stack:** PostgreSQL 15+, Supabase, pg_graphql, pgTAP for testing, pnpm workspace + Turborepo.

---

## File Structure

**Files modified:**
- `packages/core/sql/platform/tables/grants.sql` — strip overly broad authenticated grants
- `packages/core/sql/rls/policies.sql` — add RLS policy for `core.roles`
- `packages/core/sql-scripts.json` — register two new SQL files in execution order

**Files created:**
- `packages/core/sql/public/grants.sql` — anon REVOKE for admin SECURITY DEFINER functions
- `packages/core/sql/graphql/exclusions.sql` — pg_graphql `expose: false` comments for core tables
- `tests/security/01_platform_grants.sql` — verify authenticated has no direct platform access
- `tests/security/02_anon_function_execute.sql` — verify anon cannot execute admin functions
- `tests/security/03_core_roles_rls.sql` — verify authenticated can read `core.roles`
- `tests/security/04_graphql_exclusions.sql` — verify the `expose: false` comments are present

**Files NOT touched:**
- `packages/core/sql/tables/grants.sql` — core table grants stay; RLS continues as the gateway
- Any `packages/core/sql/public/functions/*.sql` — no function bodies or SECURITY mode changes
- Any RLS policy files other than `policies.sql` — adding one policy, not changing existing ones

---

## Task 1: Verify clean baseline

**Files:** none

- [ ] **Step 1: Confirm the test suite passes on the current branch**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test`
Expected: All 449 tests across 35 files pass (per the SMTA redesign completion memory).

If any failures appear here, stop and investigate before proceeding — this plan assumes a green baseline.

- [ ] **Step 2: Confirm current branch and clean working tree**

Run: `cd /home/jeff/Documents/Development/saasdb && git status`
Expected: `On branch main`, working tree clean.

---

## Task 2: Strip overly broad platform table grants (T1)

**Files:**
- Modify: `packages/core/sql/platform/tables/grants.sql`
- Test: `tests/security/01_platform_grants.sql` (create)

**Background:** `init/schemas.sql:42-43` revokes all platform access from authenticated/anon/public. But `platform/tables/grants.sql` currently re-grants `USAGE` + `SELECT, INSERT, UPDATE` on all platform tables to authenticated, undoing the lockdown. Platform functions are already `SECURITY DEFINER` and use `ensure_platform_user()` / `ensure_platform_admin()` for authorization, so authenticated never needed these table grants.

- [ ] **Step 1: Write the failing test**

Create `tests/security/01_platform_grants.sql`:

```sql
-- 01_platform_grants.sql
-- Purpose: Verify authenticated has no direct privileges on platform.* tables
-- All platform access must flow through SECURITY DEFINER functions

BEGIN;

SELECT plan(14);

-- authenticated should NOT have USAGE on platform schema
SELECT ok(
  NOT has_schema_privilege('authenticated', 'platform', 'USAGE'),
  'authenticated must NOT have USAGE on schema platform'
);

-- authenticated should NOT have SELECT on any platform table
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_users', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_users'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_roles', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_roles'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_organizations', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_organizations'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_action_logs', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_action_logs'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_settings', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_settings'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_subscription_overrides', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_subscription_overrides'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_feature_flags', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_feature_flags'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.platform_system_events', 'SELECT'),
  'authenticated must NOT have SELECT on platform.platform_system_events'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.tenant_secrets', 'SELECT'),
  'authenticated must NOT have SELECT on platform.tenant_secrets'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.billing_customers', 'SELECT'),
  'authenticated must NOT have SELECT on platform.billing_customers'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.billing_subscriptions', 'SELECT'),
  'authenticated must NOT have SELECT on platform.billing_subscriptions'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'platform.subscription_products', 'SELECT'),
  'authenticated must NOT have SELECT on platform.subscription_products'
);

-- Functions still callable (sanity: the function-based access path remains)
SELECT ok(
  has_function_privilege('authenticated', 'public.list_subscription_products()', 'EXECUTE'),
  'authenticated must still be able to EXECUTE public.list_subscription_products'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/01_platform_grants.sql`
Expected: Multiple assertions FAIL (authenticated currently HAS USAGE on platform and SELECT on platform tables).

- [ ] **Step 3: Apply the fix**

Replace the entire contents of `packages/core/sql/platform/tables/grants.sql` with:

```sql
-- grants.sql
-- Purpose: Intentionally empty.
--
-- Platform tables are locked down by init/schemas.sql:
--   REVOKE ALL ON SCHEMA platform FROM authenticated, anon, public;
--   REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, public;
--
-- All platform access flows through SECURITY DEFINER functions in
-- packages/core/sql/platform/functions/*.sql, which call platform.ensure_platform_user()
-- or platform.ensure_platform_admin() for authorization.
--
-- Authenticated users should never have direct privileges on platform.* tables.
-- Earlier broad GRANTs in this file contradicted the schema-level lockdown and
-- exposed platform tables in the pg_graphql schema (Supabase lint 0027).

-- Defensive re-revoke in case any prior grants remain in a deployed environment.
REVOKE ALL ON SCHEMA platform FROM authenticated, anon, PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM authenticated, anon, PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA platform FROM authenticated, anon, PUBLIC;

-- Cancel any default-privilege grants that future tables would otherwise inherit.
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON TABLES FROM authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA platform REVOKE ALL ON SEQUENCES FROM authenticated;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/01_platform_grants.sql`
Expected: All 14 assertions PASS.

- [ ] **Step 5: Run the full test suite to verify no regressions**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test`
Expected: All tests pass (449 + 14 new = 463). Pay particular attention to `tests/platform/*` — those tests use `set_auth_user()` for a platform user and call functions that internally access platform tables via SECURITY DEFINER, so they should continue to work.

- [ ] **Step 6: Commit**

```bash
cd /home/jeff/Documents/Development/saasdb
git add packages/core/sql/platform/tables/grants.sql tests/security/01_platform_grants.sql
git commit -m "fix(security): revoke authenticated grants on platform tables

Platform tables are now locked down exclusively at the schema level
(REVOKE ALL ON SCHEMA platform). Access flows through SECURITY DEFINER
functions that gate on platform.ensure_platform_user/admin().

Removes 13 Supabase lint 0027 (pg_graphql_authenticated_table_exposed)
warnings for platform.* tables."
```

---

## Task 3: Revoke anon EXECUTE on admin SECURITY DEFINER functions (T2)

**Files:**
- Create: `packages/core/sql/public/grants.sql`
- Modify: `packages/core/sql-scripts.json` (add the new file at the end of execution order)
- Test: `tests/security/02_anon_function_execute.sql` (create)

**Background:** Postgres grants EXECUTE on functions in the `public` schema to `PUBLIC` (which includes `anon`) by default. Six SECURITY DEFINER admin functions are flagged by lint 0028:
- `public.add_member_to_organization(uuid, uuid, uuid)`
- `public.add_member_to_unit(uuid, uuid, uuid)`
- `public.delete_organization(uuid)`
- `public.delete_unit(uuid)`
- `public.remove_member_from_organization(uuid, uuid)`
- `public.remove_member_from_unit(uuid, uuid)`

These should require authentication. The fix is `REVOKE EXECUTE ... FROM PUBLIC` followed by `GRANT EXECUTE ... TO authenticated, service_role`.

The two remaining lint 0028 hits (`public.get_invitation_details`, `public.list_subscription_products`) are intentional public endpoints (invitation landing page, public pricing page) and are accepted with a documentation comment.

- [ ] **Step 1: Write the failing test**

Create `tests/security/02_anon_function_execute.sql`:

```sql
-- 02_anon_function_execute.sql
-- Purpose: Verify anon role cannot EXECUTE admin SECURITY DEFINER functions,
-- but authenticated still can. Public-by-design functions remain anon-callable.

BEGIN;

SELECT plan(16);

-- Admin functions: anon should NOT have EXECUTE
SELECT ok(
  NOT has_function_privilege('anon', 'public.add_member_to_organization(uuid, uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute add_member_to_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.add_member_to_unit(uuid, uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute add_member_to_unit'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.delete_organization(uuid)', 'EXECUTE'),
  'anon must NOT execute delete_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.delete_unit(uuid)', 'EXECUTE'),
  'anon must NOT execute delete_unit'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.remove_member_from_organization(uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute remove_member_from_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.remove_member_from_unit(uuid, uuid)', 'EXECUTE'),
  'anon must NOT execute remove_member_from_unit'
);

-- Admin functions: authenticated MUST have EXECUTE
SELECT ok(
  has_function_privilege('authenticated', 'public.add_member_to_organization(uuid, uuid, uuid)', 'EXECUTE'),
  'authenticated must execute add_member_to_organization'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.add_member_to_unit(uuid, uuid, uuid)', 'EXECUTE'),
  'authenticated must execute add_member_to_unit'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.delete_organization(uuid)', 'EXECUTE'),
  'authenticated must execute delete_organization'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.delete_unit(uuid)', 'EXECUTE'),
  'authenticated must execute delete_unit'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.remove_member_from_organization(uuid, uuid)', 'EXECUTE'),
  'authenticated must execute remove_member_from_organization'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.remove_member_from_unit(uuid, uuid)', 'EXECUTE'),
  'authenticated must execute remove_member_from_unit'
);

-- service_role MUST retain EXECUTE on admin functions
SELECT ok(
  has_function_privilege('service_role', 'public.delete_organization(uuid)', 'EXECUTE'),
  'service_role must execute delete_organization'
);

-- Intentionally-public endpoints remain callable by both anon and authenticated
SELECT ok(
  has_function_privilege('anon', 'public.get_invitation_details(text)', 'EXECUTE'),
  'anon must still execute get_invitation_details (public invitation landing)'
);
SELECT ok(
  has_function_privilege('anon', 'public.list_subscription_products()', 'EXECUTE'),
  'anon must still execute list_subscription_products (public pricing)'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.list_subscription_products()', 'EXECUTE'),
  'authenticated must still execute list_subscription_products'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/02_anon_function_execute.sql`
Expected: First 6 assertions FAIL (anon currently has EXECUTE on admin functions via PUBLIC grant inheritance). Remaining assertions pass.

- [ ] **Step 3: Create the grants file**

Create `packages/core/sql/public/grants.sql`:

```sql
-- grants.sql
-- Purpose: EXECUTE grants for public.* SECURITY DEFINER functions.
--
-- PostgreSQL grants EXECUTE on public functions to PUBLIC (anon + authenticated)
-- by default. For admin-only SECURITY DEFINER functions, this is too permissive:
-- the unauthenticated anon role can attempt to call them. The internal auth
-- checks (is_super_admin, etc.) would still reject the call, but exposing the
-- functions to anon leaks their existence and creates an unnecessary attack
-- surface (Supabase lint 0028).
--
-- Strategy: REVOKE EXECUTE FROM PUBLIC, then GRANT to authenticated + service_role
-- for admin functions. Public-by-design endpoints (get_invitation_details,
-- list_subscription_products) keep their default PUBLIC grant.

-- ========================================
-- ADMIN FUNCTIONS: require authentication
-- ========================================
-- delete_organization
REVOKE EXECUTE ON FUNCTION public.delete_organization(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_organization(uuid) TO authenticated, service_role;

-- delete_unit
REVOKE EXECUTE ON FUNCTION public.delete_unit(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_unit(uuid) TO authenticated, service_role;

-- add_member_to_organization
REVOKE EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) TO authenticated, service_role;

-- add_member_to_unit
REVOKE EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) TO authenticated, service_role;

-- remove_member_from_organization
REVOKE EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) TO authenticated, service_role;

-- remove_member_from_unit
REVOKE EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) TO authenticated, service_role;

-- ========================================
-- INTENTIONAL PUBLIC FUNCTIONS (anon callable by design)
-- ========================================
-- These remain accessible to anon because they serve unauthenticated flows:
--   - public.get_invitation_details(text): invitation landing page before login
--   - public.list_subscription_products():  public pricing/marketing page
-- The corresponding Supabase lint 0028 warnings are accepted.
--
-- No REVOKE statements are issued for these functions; they inherit the
-- default PUBLIC EXECUTE grant established at function creation.
```

- [ ] **Step 4: Register the new file in sql-scripts.json**

Edit `packages/core/sql-scripts.json`. Append `"sql/public/grants.sql"` as the final entry in the `scripts` array (after `"sql/public/functions/products.sql"`):

```json
{
  "version": "1.0",
  "description": "Core package SQL execution order — adapter-agnostic SMTA schema",
  "scripts": [
    "sql/init/schemas.sql",
    "sql/init/auth_interface.sql",
    "sql/init/secrets_interface.sql",
    "sql/utils/functions.sql",
    "sql/platform/tables/roles.sql",
    "sql/platform/tables/users.sql",
    "sql/platform/tables/organizations.sql",
    "sql/platform/tables/action_logs.sql",
    "sql/platform/tables/settings.sql",
    "sql/platform/tables/subscription_overrides.sql",
    "sql/platform/tables/feature_flags.sql",
    "sql/platform/tables/system_events.sql",
    "sql/tables/organizations.sql",
    "sql/tables/units.sql",
    "sql/tables/roles.sql",
    "sql/tables/memberships.sql",
    "sql/tables/users_meta.sql",
    "sql/tables/organization_files.sql",
    "sql/tables/organizations_meta.sql",
    "sql/tables/audit_logs.sql",
    "sql/tables/invitations.sql",
    "sql/tables/grants.sql",
    "sql/triggers/new_user.sql",
    "sql/triggers/new_organization.sql",
    "sql/triggers/new_unit.sql",
    "sql/triggers/protect_super_admin.sql",
    "sql/platform/tables/tenant_secrets.sql",
    "sql/platform/tables/billing_customers.sql",
    "sql/platform/tables/billing_subscriptions.sql",
    "sql/platform/tables/subscription_products.sql",
    "sql/platform/tables/grants.sql",
    "sql/rls/helpers.sql",
    "sql/rls/policies.sql",
    "sql/rls/invitations.sql",
    "sql/platform/rls/lockdown.sql",
    "sql/functions/log_audit.sql",
    "sql/functions/secrets.sql",
    "sql/functions/invitations.sql",
    "sql/public/functions/user_profile.sql",
    "sql/public/functions/organizations.sql",
    "sql/public/functions/units.sql",
    "sql/public/functions/files.sql",
    "sql/public/functions/audit.sql",
    "sql/public/functions/secrets.sql",
    "sql/public/functions/invitations.sql",
    "sql/platform/functions/log_action.sql",
    "sql/platform/functions/users.sql",
    "sql/platform/functions/organizations.sql",
    "sql/platform/functions/overrides.sql",
    "sql/platform/functions/feature_flags.sql",
    "sql/platform/functions/events.sql",
    "sql/platform/functions/audit.sql",
    "sql/platform/functions/settings.sql",
    "sql/platform/functions/billing.sql",
    "sql/platform/functions/products.sql",
    "sql/public/functions/products.sql",
    "sql/public/grants.sql"
  ]
}
```

(The only changed line is the addition of `"sql/public/grants.sql"` as the final array entry. Make sure the comma is added to the prior line.)

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/02_anon_function_execute.sql`
Expected: All 16 assertions PASS.

- [ ] **Step 6: Run the full test suite**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test`
Expected: All tests pass. The existing function-call tests (e.g. `tests/functions/*`, `tests/membership/*`) all run under `set_auth_user()` (authenticated context), so revoking anon's EXECUTE should not affect them.

- [ ] **Step 7: Commit**

```bash
cd /home/jeff/Documents/Development/saasdb
git add packages/core/sql/public/grants.sql packages/core/sql-scripts.json tests/security/02_anon_function_execute.sql
git commit -m "fix(security): revoke anon EXECUTE on admin SECURITY DEFINER functions

Adds packages/core/sql/public/grants.sql with explicit
REVOKE/GRANT pairs for six admin-only public functions
(delete_organization, delete_unit, add/remove_member_from_*).
Authenticated and service_role retain access; anon does not.

Public-by-design endpoints get_invitation_details and
list_subscription_products are deliberately untouched.

Removes 6 Supabase lint 0028 (anon_security_definer_function_executable)
warnings."
```

---

## Task 4: Add RLS SELECT policy for core.roles (T3)

**Files:**
- Modify: `packages/core/sql/rls/policies.sql`
- Test: `tests/security/03_core_roles_rls.sql` (create)

**Background:** The Supabase Security Advisor Info item reports that `core.roles` has RLS enabled but no policies. RLS with no policies defaults to deny-all, contradicting the existing `GRANT SELECT ON core.roles TO authenticated` in `tables/grants.sql:20`. `core.roles` is reference data — role names and CASL rules — that org members need to read (e.g., for `list_organization_members`, `get_user_permissions`). The fix is to enable RLS explicitly in policies.sql (since the database currently has it enabled out-of-band) and add a permissive SELECT policy.

- [ ] **Step 1: Write the failing test**

Create `tests/security/03_core_roles_rls.sql`:

```sql
-- 03_core_roles_rls.sql
-- Purpose: Verify RLS is enabled on core.roles AND a SELECT policy exists
-- so authenticated users can read role reference data.

BEGIN;

SELECT plan(4);

-- RLS is enabled
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'core.roles'::regclass),
  'core.roles must have RLS enabled'
);

-- A SELECT policy exists
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'core'
      AND tablename = 'roles'
      AND cmd = 'SELECT'
  ),
  'core.roles must have at least one SELECT policy'
);

-- authenticated can SELECT (the policy actually allows reads)
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT ok(
  (SELECT count(*) FROM core.roles WHERE is_deleted = false) > 0,
  'authenticated user can SELECT non-deleted rows from core.roles'
);

-- A specific role lookup works (mirrors what list_organization_members does)
SELECT ok(
  EXISTS (SELECT 1 FROM core.roles WHERE name = 'super_admin' AND is_deleted = false),
  'authenticated user can find super_admin role by name'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/03_core_roles_rls.sql`
Expected: The first two assertions may pass or fail depending on whether RLS was enabled out-of-band on the test DB. The third and fourth (`authenticated can SELECT`) will FAIL if RLS is enabled without a policy.

- [ ] **Step 3: Add the RLS enablement and policy**

Edit `packages/core/sql/rls/policies.sql`. In the `RLS ENABLEMENT` block (lines 17-28), add `core.roles`:

Find:
```sql
-- ========================================
-- RLS ENABLEMENT
-- ========================================
ALTER TABLE core.users_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organization_files ENABLE ROW LEVEL SECURITY;
```

Replace with:
```sql
-- ========================================
-- RLS ENABLEMENT
-- ========================================
ALTER TABLE core.users_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.unit_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organization_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.roles ENABLE ROW LEVEL SECURITY;
```

Then, at the very end of the file (after the `organization_files` policy block), append:

```sql

-- ========================================
-- POLICIES: roles
-- ========================================
-- core.roles is shared reference data (role names + CASL rule definitions).
-- Any authenticated user needs SELECT access to resolve their role and
-- render UI based on CASL rules. There is no tenant scoping on this table.
-- INSERT/UPDATE/DELETE are not permitted via RLS — role mutations must go
-- through admin tooling/seed scripts.
CREATE POLICY roles_select ON core.roles
  FOR SELECT USING (is_deleted = false);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/03_core_roles_rls.sql`
Expected: All 4 assertions PASS.

- [ ] **Step 5: Run the full test suite**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test`
Expected: All tests pass. Functions that JOIN on `core.roles` (e.g. `list_organization_members`, `get_user_permissions`) continue to work because authenticated can read non-deleted roles.

- [ ] **Step 6: Commit**

```bash
cd /home/jeff/Documents/Development/saasdb
git add packages/core/sql/rls/policies.sql tests/security/03_core_roles_rls.sql
git commit -m "fix(security): add SELECT RLS policy for core.roles

core.roles is shared reference data (role names + CASL rules) that any
authenticated user needs to read for permission resolution. Enabling RLS
without a policy created a deny-all state that contradicted the existing
SELECT grant.

Resolves the Supabase Security Advisor Info finding on core.roles."
```

---

## Task 5: Add pg_graphql exclusion comments for core tables (T4)

**Files:**
- Create: `packages/core/sql/graphql/exclusions.sql`
- Modify: `packages/core/sql-scripts.json` (register the new file)
- Test: `tests/security/04_graphql_exclusions.sql` (create)

**Background:** All 11 `core.*` tables have `SELECT` granted to `authenticated` (intentionally — `SECURITY INVOKER` public functions need it, and RLS policies do the gateway work). This causes lint 0027 (`pg_graphql_authenticated_table_exposed`) to flag every table because pg_graphql builds its schema from anything `authenticated` can read.

pg_graphql honors a `COMMENT ON TABLE ... IS '@graphql({"expose": false})'` directive that excludes the table from the generated GraphQL schema. Applying this comment per table removes the lint warning without revoking grants, without changing function security mode, and without touching RLS — the existing design stays intact.

- [ ] **Step 1: Write the failing test**

Create `tests/security/04_graphql_exclusions.sql`:

```sql
-- 04_graphql_exclusions.sql
-- Purpose: Verify all 11 core.* tables carry the pg_graphql exclusion comment
-- so they do not appear in the generated GraphQL schema.

BEGIN;

SELECT plan(11);

SELECT is(
  obj_description('core.audit_logs'::regclass),
  '@graphql({"expose": false})',
  'core.audit_logs is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.invitations'::regclass),
  '@graphql({"expose": false})',
  'core.invitations is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.memberships'::regclass),
  '@graphql({"expose": false})',
  'core.memberships is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.organization_files'::regclass),
  '@graphql({"expose": false})',
  'core.organization_files is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.organizations'::regclass),
  '@graphql({"expose": false})',
  'core.organizations is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.organizations_meta'::regclass),
  '@graphql({"expose": false})',
  'core.organizations_meta is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.roles'::regclass),
  '@graphql({"expose": false})',
  'core.roles is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.unit_memberships'::regclass),
  '@graphql({"expose": false})',
  'core.unit_memberships is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.unit_meta'::regclass),
  '@graphql({"expose": false})',
  'core.unit_meta is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.units'::regclass),
  '@graphql({"expose": false})',
  'core.units is excluded from pg_graphql'
);
SELECT is(
  obj_description('core.users_meta'::regclass),
  '@graphql({"expose": false})',
  'core.users_meta is excluded from pg_graphql'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/04_graphql_exclusions.sql`
Expected: All 11 assertions FAIL (no comments are set yet).

- [ ] **Step 3: Create the exclusions file**

Create `packages/core/sql/graphql/exclusions.sql`:

```sql
-- exclusions.sql
-- Purpose: Hide core.* tables from the pg_graphql-generated GraphQL schema.
--
-- Design context:
--   - Every public-facing operation must go through public.* RPC functions.
--   - core.* tables retain SELECT for authenticated because SECURITY INVOKER
--     functions need it; RLS policies are the row-level access gateway.
--   - Without these comments, pg_graphql would auto-expose core.* tables to
--     authenticated users in the GraphQL schema (Supabase lint 0027). RLS
--     would still protect the data, but exposing the schema is unnecessary
--     and inconsistent with the function-first API design.
--
-- Mechanism:
--   pg_graphql reads COMMENT ON TABLE directives. A JSON payload of
--   {"expose": false} tells the extension to skip the table when building
--   the GraphQL schema. The table remains fully usable via SQL and via
--   SECURITY INVOKER functions; only the GraphQL surface is suppressed.
--
-- Platform tables (platform.*) are NOT listed here because Task 2
-- (platform grants) revokes all authenticated access at the schema level,
-- which already removes them from pg_graphql.

COMMENT ON TABLE core.organizations       IS '@graphql({"expose": false})';
COMMENT ON TABLE core.organizations_meta  IS '@graphql({"expose": false})';
COMMENT ON TABLE core.units               IS '@graphql({"expose": false})';
COMMENT ON TABLE core.unit_meta           IS '@graphql({"expose": false})';
COMMENT ON TABLE core.memberships         IS '@graphql({"expose": false})';
COMMENT ON TABLE core.unit_memberships    IS '@graphql({"expose": false})';
COMMENT ON TABLE core.users_meta          IS '@graphql({"expose": false})';
COMMENT ON TABLE core.audit_logs          IS '@graphql({"expose": false})';
COMMENT ON TABLE core.organization_files  IS '@graphql({"expose": false})';
COMMENT ON TABLE core.invitations         IS '@graphql({"expose": false})';
COMMENT ON TABLE core.roles               IS '@graphql({"expose": false})';
```

- [ ] **Step 4: Register the new file in sql-scripts.json**

Edit `packages/core/sql-scripts.json` to append `"sql/graphql/exclusions.sql"` as the final entry (after `"sql/public/grants.sql"` added in Task 3). The complete `scripts` array should end with:

```json
    "sql/public/functions/products.sql",
    "sql/public/grants.sql",
    "sql/graphql/exclusions.sql"
  ]
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test -- tests/security/04_graphql_exclusions.sql`
Expected: All 11 assertions PASS.

- [ ] **Step 6: Run the full test suite**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test`
Expected: All tests pass. The comments are metadata only — they cannot affect any SQL query, RLS policy, or function behavior.

- [ ] **Step 7: Commit**

```bash
cd /home/jeff/Documents/Development/saasdb
git add packages/core/sql/graphql/exclusions.sql packages/core/sql-scripts.json tests/security/04_graphql_exclusions.sql
git commit -m "fix(security): exclude core.* tables from pg_graphql schema

Adds COMMENT ON TABLE ... '@graphql({\"expose\": false})' to all 11
core.* tables. pg_graphql honors this directive and skips the tables
when building its schema, removing them from the GraphQL surface.

Tables remain accessible via SQL and via SECURITY INVOKER public
functions; RLS policies continue to gate row-level access exactly as
before. No grants, function bodies, or policies were modified.

Removes the remaining 11 Supabase lint 0027
(pg_graphql_authenticated_table_exposed) warnings for core.* tables."
```

---

## Task 6: End-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Confirm the full test suite is green**

Run: `cd /home/jeff/Documents/Development/saasdb && npm test`
Expected: All tests pass. New count: 449 + 14 + 16 + 4 + 11 = 494 tests across 39 files.

- [ ] **Step 2: Confirm git log shows four clean commits**

Run: `cd /home/jeff/Documents/Development/saasdb && git log --oneline -6`
Expected: Four new commits on top of the prior `main` HEAD, one per task (T1–T4).

- [ ] **Step 3: Re-run Supabase Security Advisor on the deployed database**

This step is performed in the Supabase Dashboard, not via CLI. After applying the migrations to a Supabase project:

1. Open the project in the Supabase Dashboard
2. Navigate to **Database → Advisors → Security Advisor**
3. Click **Refresh** to re-run the analyzer

Expected results:
- **Errors:** 0 (unchanged — none reported originally)
- **Warnings:** Reduced from 39 to ~14
  - **0 lint 0027** (`pg_graphql_authenticated_table_exposed`) for `core.*` and `platform.*` tables — all resolved
  - **2 lint 0028** remaining (`get_invitation_details`, `list_subscription_products`) — intentionally accepted
  - **~12 lint 0029** remaining (`authenticated_security_definer_function_executable`) — intentionally accepted; functions have internal authorization checks
- **Info:** 0 (the `core.roles` finding is resolved)

If lint 0027 still fires after applying the comments, see "Fallback" below.

- [ ] **Step 4: Update the SMTA progress memory**

Update `/home/jeff/.claude/projects/-home-jeff-Documents-Development-saasdb/memory/project_smta_redesign_progress.md` to record that the Security Advisor remediation is complete, listing the 4 commits and the accepted warnings (the 2 anon-public functions and the lint 0029 design decision).

---

## Fallback (only if lint 0027 still fires after Task 5)

If the Supabase Security Advisor still flags `core.*` tables for lint 0027 after the pg_graphql exclusion comments are applied, the linter is inspecting raw grants rather than the pg_graphql schema, and the comment-based approach cannot resolve it. In that case, the only SQL-only fix is the more invasive refactor previously deferred:

1. `REVOKE USAGE ON SCHEMA core FROM authenticated` in `init/schemas.sql`
2. Remove the `ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT` line from `init/schemas.sql`
3. Convert every `SECURITY INVOKER` public function that touches `core.*` to `SECURITY DEFINER`
4. Add explicit `IF NOT core.is_org_member(...) THEN RAISE EXCEPTION` checks to functions that previously relied on RLS for row filtering (~12 functions identified earlier: `get_organization`, `list_organization_members`, `get_user_role`, `get_user_permissions`, `get_user_unit_permissions`, `create_organization`, `get_unit`, `list_unit_members`, `create_unit`, `assign_user_to_unit`, `list_invitations`, `create_invitation`)
5. Revoke `SELECT` from authenticated in `tables/grants.sql`
6. Re-run the full test suite — expect to fix multiple regressions

This fallback is documented but explicitly out of scope for this plan. Decide based on observed Security Advisor behavior whether to schedule it as a follow-up.

---

## Summary of Changes

| Task | Files touched | Warnings resolved |
|---|---|---|
| T1 | `platform/tables/grants.sql` | 13 × lint 0027 (platform tables) |
| T2 | `public/grants.sql` (new), `sql-scripts.json` | 6 × lint 0028 (admin functions) |
| T3 | `rls/policies.sql` | 1 × Info (`core.roles` RLS) |
| T4 | `graphql/exclusions.sql` (new), `sql-scripts.json` | 11 × lint 0027 (core tables) |

**Resolved:** 31 of 39 advisor findings.
**Accepted with documentation:**
- 2 × lint 0028 (`get_invitation_details`, `list_subscription_products` — intentional public endpoints)
- ~12 × lint 0029 (DEFINER admin functions with internal `is_super_admin()` / `ensure_platform_admin()` checks)

The RLS-as-gateway design is preserved unchanged. No function bodies are modified. No SECURITY mode is changed. No core table grants are revoked.
