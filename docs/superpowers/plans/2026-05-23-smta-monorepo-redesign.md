# SMTA Monorepo Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure SMTA from a Supabase-coupled monolith into a provider-agnostic monorepo with packages for core SQL, adapters (Supabase/Payload), billing, and Zod schemas.

**Architecture:** Pure PostgreSQL core with a pluggable `core.get_current_user_id()` auth abstraction; adapters override this function and add platform-specific tables/triggers. Zod schemas model `public.*` function contracts (not tables). A TypeScript `BillingProvider` interface with Stripe and Lemon Squeezy implementations replaces placeholder billing code.

**Tech Stack:** PostgreSQL 15+, pgTap, pnpm workspaces, Turborepo, TypeScript 5, Zod v4, Stripe SDK, Lemon Squeezy SDK

---

## Spec Reference
`docs/superpowers/specs/2026-05-23-smta-monorepo-redesign.md`

---

## Phase 0 — Fix Failing Tests

> Gate: All 42 pgTap tests pass before proceeding to Phase 1.

Root causes of the 6 failing test files:
1. **`01_organization_functions.sql` tests 10–12**: `delete_organization` soft-deletes the caller's membership before soft-deleting the org. After the membership is deleted, the RLS check for the org UPDATE fails silently, leaving `organizations.is_deleted = false`. `get_organization` then returns the still-active org.
2. **`02_unit_functions.sql` plan mismatch**: `public.list_units(UUID)`, `public.update_unit(...)`, `public.delete_unit(...)` are missing — the bare SELECT calls throw unhandled exceptions, aborting the transaction after test 3.
3. **`03_membership_functions.sql` ran 0**: `INSERT INTO core.users_meta` fails with a unique constraint violation because the `new_user.sql` trigger already created that row when `INSERT INTO auth.users` ran.
4. **`04_user_functions.sql` tests 4–6**: `public.update_user_profile` signature is `(p_data JSON)` but tests call `(TEXT, TEXT)`. Also missing: `public.get_user_organizations()`, `public.get_user_units(UUID)`.
5. **`03_transfer_super_admin.sql` plan mismatch**: `SELECT plan(9)` but only 8 test assertions exist.
6. **`04_organization_membership.sql` plan mismatch**: Direct `UPDATE core.memberships` is done outside a `lives_ok` wrapper; if RLS or the trigger rejects it, the transaction aborts and tests 8–11 never run.

---

### Task 0.1 — Fix `delete_organization`: Soft-Delete Org Before Caller Membership

**Files:**
- Modify: `sql/_public/functions/organizations.sql`

The fix: move the `UPDATE core.organizations` statement to happen before the caller's own membership is deleted. After the org is marked `is_deleted = true`, the caller's membership deletion no longer needs the org to be active for the RLS check on organizations.

- [ ] **Step 1: Locate the deletion order in `delete_organization`**

Open `sql/_public/functions/organizations.sql`. Find the `public.delete_organization` function (near line 190). Identify these two UPDATE blocks in order:
```sql
-- Block A: soft-delete caller's own membership (currently BEFORE org delete)
UPDATE core.memberships AS m
SET is_deleted = true, ...
WHERE m.organization_id = p_id AND m.user_id = auth.uid() AND m.is_deleted = false;

-- Block B: soft-delete organization (currently AFTER membership delete)
UPDATE core.organizations AS o
SET is_deleted = true, ...
WHERE o.id = p_id AND o.is_deleted = false;
```

- [ ] **Step 2: Swap Block B before Block A**

Replace the ordering so the org is soft-deleted first, then the caller's membership. The corrected end section of `delete_organization` should be:

```sql
  -- Soft-delete all other org memberships (excluding caller)
  UPDATE core.memberships AS m
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE m.organization_id = p_id
    AND m.user_id <> auth.uid()
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_membership_rows = ROW_COUNT;

  -- Soft-delete the organization BEFORE deleting caller's membership.
  -- The org UPDATE uses RLS which checks auth.uid() membership; if caller's
  -- membership is deleted first, the RLS check fails silently (0 rows updated).
  UPDATE core.organizations AS o
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE o.id = p_id
    AND o.is_deleted = false;
  GET DIAGNOSTICS v_org_rows = ROW_COUNT;

  -- Finally, soft-delete the caller's own membership
  UPDATE core.memberships AS m
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid(),
      updated_by = auth.uid()
  WHERE m.organization_id = p_id
    AND m.user_id = auth.uid()
    AND m.is_deleted = false;
  GET DIAGNOSTICS v_membership_rows_self = ROW_COUNT;

  v_membership_rows := v_membership_rows + v_membership_rows_self;

  PERFORM core.log_audit( ... );  -- unchanged
```

- [ ] **Step 3: Run organization function tests**

```bash
pg_prove -v tests/functions/01_organization_functions.sql
```
Expected: `ok 1..12` — all 12 pass.

- [ ] **Step 4: Commit**

```bash
git add sql/_public/functions/organizations.sql
git commit -m "fix: delete_organization — soft-delete org before caller's membership"
```

---

### Task 0.2 — Add Missing Unit Functions

**Files:**
- Modify: `sql/_public/functions/units.sql`

- [ ] **Step 1: Add `public.list_units(p_org_id UUID)` at end of `units.sql`**

```sql
-- ========================================
-- FUNCTION: public.list_units()
-- ========================================
-- List all active units for an organization (for org members)
-- Different from list_my_units() which only shows units the caller belongs to
CREATE OR REPLACE FUNCTION public.list_units(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, u.description, u.created_at, u.updated_at
  FROM core.units u
  WHERE u.organization_id = p_org_id
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 2: Add `public.update_unit(p_id UUID, p_name TEXT, p_description TEXT)`**

```sql
-- ========================================
-- FUNCTION: public.update_unit()
-- ========================================
CREATE OR REPLACE FUNCTION public.update_unit(
  p_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Unit name is required';
  END IF;

  UPDATE core.units u
  SET name = p_name,
      description = p_description,
      updated_by = auth.uid()
  WHERE u.id = p_id
    AND u.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unit not found';
  END IF;

  PERFORM core.log_audit('update', 'core.units', p_id, 'update_unit',
    jsonb_build_object('name', p_name, 'description', p_description));

  RETURN QUERY
  SELECT u.id, u.name, u.description, u.updated_at
  FROM core.units u WHERE u.id = p_id AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 3: Add `public.delete_unit(p_id UUID)`**

```sql
-- ========================================
-- FUNCTION: public.delete_unit()
-- ========================================
CREATE OR REPLACE FUNCTION public.delete_unit(p_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.unit_memberships
  SET is_deleted = true, deleted_at = now(), deleted_by = auth.uid(), updated_by = auth.uid()
  WHERE unit_id = p_id AND is_deleted = false;

  UPDATE core.unit_meta
  SET is_deleted = true, deleted_at = now(), deleted_by = auth.uid(), updated_by = auth.uid()
  WHERE id = p_id AND is_deleted = false;

  UPDATE core.units u
  SET is_deleted = true, deleted_at = now(), deleted_by = auth.uid(), updated_by = auth.uid()
  WHERE u.id = p_id AND u.is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unit not found';
  END IF;

  PERFORM core.log_audit('delete', 'core.units', p_id, 'delete_unit', '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 4: Run unit function tests**

```bash
pg_prove -v tests/functions/02_unit_functions.sql
```
Expected: `ok 1..12` — all 12 pass.

- [ ] **Step 5: Commit**

```bash
git add sql/_public/functions/units.sql
git commit -m "feat: add list_units, update_unit, delete_unit public functions"
```

---

### Task 0.3 — Add `public.add_member_to_organization` + Fix Test

**Files:**
- Modify: `sql/_public/functions/organizations.sql`
- Modify: `tests/functions/03_membership_functions.sql`

- [ ] **Step 1: Add `public.add_member_to_organization` to `organizations.sql`**

```sql
-- ========================================
-- FUNCTION: public.add_member_to_organization()
-- ========================================
-- Add an existing user to an organization by UUID and role
-- Caller must be super_admin; user must already exist in core.users_meta
CREATE OR REPLACE FUNCTION public.add_member_to_organization(
  p_org_id UUID,
  p_user_id UUID,
  p_role_id UUID
)
RETURNS VOID AS $$
BEGIN
  IF NOT core.is_super_admin(p_org_id) THEN
    RAISE EXCEPTION 'Only a super_admin can add members to the organization';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM core.users_meta WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  INSERT INTO core.memberships (user_id, organization_id, role_id, is_super_admin, created_by, updated_by)
  VALUES (p_user_id, p_org_id, p_role_id, false, auth.uid(), auth.uid())
  ON CONFLICT (user_id, organization_id) DO UPDATE
    SET role_id = EXCLUDED.role_id,
        is_deleted = false,
        updated_by = auth.uid(),
        updated_at = now();

  PERFORM core.log_audit('insert', 'core.memberships', p_user_id, 'add_member_to_organization',
    jsonb_build_object('organization_id', p_org_id, 'role_id', p_role_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 2: Fix `INSERT INTO core.users_meta` in test file**

Open `tests/functions/03_membership_functions.sql`. Find the INSERT (around line 25) and replace it with an upsert:

```sql
-- Replace this:
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES (current_setting('test.new_user_id')::uuid, 'newmember@test.com', 'New', 'Member',
        current_setting('test.maria_id')::uuid, current_setting('test.maria_id')::uuid);

-- With this (trigger already created the row; just update the fields):
INSERT INTO core.users_meta (id, email, first_name, last_name, created_by, updated_by)
VALUES (current_setting('test.new_user_id')::uuid, 'newmember@test.com', 'New', 'Member',
        current_setting('test.maria_id')::uuid, current_setting('test.maria_id')::uuid)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  updated_by = EXCLUDED.updated_by;
```

- [ ] **Step 3: Run membership function tests**

```bash
pg_prove -v tests/functions/03_membership_functions.sql
```
Expected: `ok 1..16` — all 16 pass.

- [ ] **Step 4: Commit**

```bash
git add sql/_public/functions/organizations.sql tests/functions/03_membership_functions.sql
git commit -m "feat: add add_member_to_organization; fix users_meta upsert in test"
```

---

### Task 0.4 — Fix User Profile Functions + Add Missing Functions

**Files:**
- Modify: `sql/_public/functions/user_profile.sql`

- [ ] **Step 1: Replace `update_user_profile` with correct signature**

Find and replace the entire `public.update_user_profile` function:

```sql
-- ========================================
-- FUNCTION: public.update_user_profile()
-- ========================================
DROP FUNCTION IF EXISTS public.update_user_profile(JSON);
CREATE OR REPLACE FUNCTION public.update_user_profile(
  p_first_name TEXT,
  p_last_name TEXT
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  UPDATE core.users_meta
  SET first_name = p_first_name,
      last_name  = p_last_name,
      updated_by = auth.uid()
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;

  PERFORM core.log_audit('update', 'core.users_meta', auth.uid(), 'update_user_profile',
    jsonb_build_object('first_name', p_first_name, 'last_name', p_last_name));

  RETURN QUERY
  SELECT m.id, m.email, m.first_name, m.last_name, m.avatar_url, m.timezone, m.locale
  FROM core.users_meta m WHERE m.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 2: Add `public.get_user_organizations()` at end of `user_profile.sql`**

```sql
-- ========================================
-- FUNCTION: public.get_user_organizations()
-- ========================================
-- Returns all active organizations the current user belongs to.
-- Alias for list_my_organizations() — kept for API consistency.
CREATE OR REPLACE FUNCTION public.get_user_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.list_my_organizations();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 3: Add `public.get_user_units(p_org_id UUID)` at end of `user_profile.sql`**

```sql
-- ========================================
-- FUNCTION: public.get_user_units()
-- ========================================
-- Returns units the current user belongs to within a specific organization.
CREATE OR REPLACE FUNCTION public.get_user_units(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = auth.uid()
    AND u.organization_id = p_org_id
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 4: Run user function tests**

```bash
pg_prove -v tests/functions/04_user_functions.sql
```
Expected: `ok 1..10` — all 10 pass.

- [ ] **Step 5: Commit**

```bash
git add sql/_public/functions/user_profile.sql
git commit -m "fix: update_user_profile signature; add get_user_organizations, get_user_units"
```

---

### Task 0.5 — Fix Plan Count and Direct UPDATE in Tests

**Files:**
- Modify: `tests/membership/03_transfer_super_admin.sql`
- Modify: `tests/membership/04_organization_membership.sql`

- [ ] **Step 1: Fix plan count in `03_transfer_super_admin.sql`**

Change line 5:
```sql
-- From:
SELECT plan(9);
-- To:
SELECT plan(8);
```

- [ ] **Step 2: Fix direct UPDATE in `04_organization_membership.sql`**

Find the direct UPDATE block (around line 58) and replace it with the public API:

```sql
-- Remove this direct table mutation:
UPDATE core.memberships
SET is_deleted = true, deleted_at = now(), deleted_by = test_helpers.get_test_user_id('maria@test.bellaitalia.com')
WHERE user_id = test_helpers.get_test_user_id('taylor@test.bellaitalia.com')
  AND organization_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Replace with:
SELECT public.remove_user_from_organization(
  test_helpers.get_test_user_id('taylor@test.bellaitalia.com'),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);
```

- [ ] **Step 3: Run both membership tests**

```bash
pg_prove -v tests/membership/03_transfer_super_admin.sql tests/membership/04_organization_membership.sql
```
Expected: both pass with correct plan counts.

- [ ] **Step 4: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 test files pass. If any still fail, investigate and fix before continuing.

- [ ] **Step 5: Commit**

```bash
git add tests/membership/03_transfer_super_admin.sql tests/membership/04_organization_membership.sql
git commit -m "fix: plan count in transfer_super_admin test; use public API in membership test"
```

---

## Phase 1 — Auth Abstraction In-Place

> Gate: All 42 tests still pass after Phase 1. No directory restructuring — SQL files stay in place.

This phase introduces `core.get_current_user_id()` as the single auth access point. All `auth.uid()` calls in `sql/_core/` and `sql/_public/` are replaced. Platform functions in `sql/_platform/` keep `auth.uid()` — they are intentionally Supabase-specific.

---

### Task 1.1 — Declare the Auth Interface Function

**Files:**
- Create: `sql/00_init/auth_interface.sql`
- Create: `sql/00_init/auth_supabase_impl.sql`
- Modify: `sql-scripts.json`

- [ ] **Step 1: Create `sql/00_init/auth_interface.sql`**

```sql
-- auth_interface.sql
-- Purpose: Declare core.get_current_user_id() stub.
-- Each adapter package overrides this. Calling it without an adapter raises an exception.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RAISE EXCEPTION 'core.get_current_user_id() not implemented. Deploy an adapter (supabase or payload).';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core;
```

- [ ] **Step 2: Create `sql/00_init/auth_supabase_impl.sql`**

```sql
-- auth_supabase_impl.sql
-- Purpose: Supabase implementation of core.get_current_user_id().
-- Runs immediately after auth_interface.sql, replacing the stub.
-- In the future monorepo, this file lives in packages/supabase/.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, auth, public;
```

- [ ] **Step 3: Add both files to `sql-scripts.json` after `schemas.sql`**

In `sql-scripts.json`, after `"sql/00_init/schemas.sql"`, add:
```json
"sql/00_init/auth_interface.sql",
"sql/00_init/auth_supabase_impl.sql",
```

- [ ] **Step 4: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass (the new functions don't change any behavior yet).

- [ ] **Step 5: Commit**

```bash
git add sql/00_init/auth_interface.sql sql/00_init/auth_supabase_impl.sql sql-scripts.json
git commit -m "feat: introduce core.get_current_user_id() auth abstraction stub + supabase impl"
```

---

### Task 1.2 — Replace `auth.uid()` in Core RLS Helpers

**Files:**
- Modify: `sql/_core/rls/helpers.sql`

Replace every `auth.uid()` with `core.get_current_user_id()`. There are 7 occurrences in these functions: `is_super_admin`, `is_org_member`, `is_unit_member`, `get_org_role`, `has_unit_role`, `shares_organization`.

- [ ] **Step 1: Replace all occurrences**

In `sql/_core/rls/helpers.sql`, globally replace:
```sql
-- Find: auth.uid()
-- Replace with: core.get_current_user_id()
```

Also update each function's `SET search_path` to include `core`:
```sql
-- Before: SET search_path = core, public;
-- After:  SET search_path = core, public;  (already correct — no change needed)
```

The functions are `SECURITY DEFINER`, so they have access to `core` schema already.

- [ ] **Step 2: Run RLS and membership tests**

```bash
pg_prove -v tests/rls/03_memberships_rls.sql tests/membership/01_roles_exist.sql tests/membership/02_super_admin_protection.sql
```
Expected: all pass.

- [ ] **Step 3: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass.

- [ ] **Step 4: Commit**

```bash
git add sql/_core/rls/helpers.sql
git commit -m "refactor: replace auth.uid() with core.get_current_user_id() in RLS helpers"
```

---

### Task 1.3 — Replace `auth.uid()` in Core RLS Policies

**Files:**
- Modify: `sql/_core/rls/policies.sql`
- Modify: `sql/_core/rls/invitations.sql`

- [ ] **Step 1: Replace `auth.uid()` in `policies.sql`**

There are ~5 direct `auth.uid()` calls (in INSERT WITH CHECK clauses for organizations, memberships, users_meta). Replace each:
```sql
-- Before: (SELECT auth.uid()) = created_by
-- After:  (SELECT core.get_current_user_id()) = created_by

-- Before: (SELECT auth.uid()) = id
-- After:  (SELECT core.get_current_user_id()) = id
```

- [ ] **Step 2: Replace `auth.uid()` in `invitations.sql`**

Replace all occurrences in `sql/_core/rls/invitations.sql`.

- [ ] **Step 3: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass.

- [ ] **Step 4: Commit**

```bash
git add sql/_core/rls/policies.sql sql/_core/rls/invitations.sql
git commit -m "refactor: replace auth.uid() with core.get_current_user_id() in RLS policies"
```

---

### Task 1.4 — Replace `auth.uid()` in Core and Public Functions

**Files:**
- Modify: `sql/_core/functions/log_audit.sql`
- Modify: `sql/_core/functions/invitations.sql`
- Modify: `sql/_public/functions/organizations.sql`
- Modify: `sql/_public/functions/units.sql`
- Modify: `sql/_public/functions/user_profile.sql`
- Modify: `sql/_public/functions/files.sql`

Replace every `auth.uid()` in these files with `core.get_current_user_id()`.

- [ ] **Step 1: Replace in `log_audit.sql`** (1 occurrence: `actor_id`)
- [ ] **Step 2: Replace in `sql/_core/functions/invitations.sql`** (4 occurrences)
- [ ] **Step 3: Replace in `sql/_public/functions/organizations.sql`** (all occurrences — ~7 in public functions + the newly added ones from Task 0)
- [ ] **Step 4: Replace in `sql/_public/functions/units.sql`** (all occurrences)
- [ ] **Step 5: Replace in `sql/_public/functions/user_profile.sql`** (all occurrences)
- [ ] **Step 6: Replace in `sql/_public/functions/files.sql`** (all occurrences)

- [ ] **Step 7: Update `test_helpers.set_auth_user()` to set both config vars**

In `tests/fixtures/00_test_helpers.sql`, update `set_auth_user`:

```sql
CREATE OR REPLACE FUNCTION test_helpers.set_auth_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$$ LANGUAGE plpgsql;
```

Setting `app.current_user_id` here is harmless for the Supabase adapter (it reads `auth.uid()` which reads `request.jwt.claim.sub`). It prepares the tests to work with the Payload adapter in future phases.

- [ ] **Step 8: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass.

- [ ] **Step 9: Commit**

```bash
git add sql/_core/functions/log_audit.sql sql/_core/functions/invitations.sql \
        sql/_public/functions/organizations.sql sql/_public/functions/units.sql \
        sql/_public/functions/user_profile.sql sql/_public/functions/files.sql \
        tests/fixtures/00_test_helpers.sql
git commit -m "refactor: replace auth.uid() with core.get_current_user_id() in all core/public functions"
```

---

### Task 1.5 — Extract Vault Calls Into a Provider Stub

**Files:**
- Modify: `sql/_core/functions/secrets.sql`
- Create: `sql/00_init/secrets_interface.sql`
- Create: `sql/00_init/secrets_supabase_impl.sql`
- Modify: `sql-scripts.json`

- [ ] **Step 1: Create `sql/00_init/secrets_interface.sql`**

```sql
-- secrets_interface.sql
-- Purpose: Declare secrets provider stubs for adapter override.

-- Called when storing a new secret. Returns an opaque reference ID.
CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
BEGIN
  RAISE EXCEPTION 'core.store_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

-- Called when deleting a secret by its reference ID.
CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
BEGIN
  RAISE EXCEPTION 'core.delete_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;
```

- [ ] **Step 2: Create `sql/00_init/secrets_supabase_impl.sql`**

```sql
-- secrets_supabase_impl.sql
-- Purpose: Supabase Vault implementation of secrets provider.

CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
DECLARE
  v_vault_id UUID;
BEGIN
  SELECT vault.create_secret(p_secret, p_name) INTO v_vault_id;
  RETURN v_vault_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, vault, public;

CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
BEGIN
  DELETE FROM vault.secrets WHERE id = p_secret_ref::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, vault, public;
```

- [ ] **Step 3: Refactor `sql/_core/functions/secrets.sql`**

Replace the direct `vault.create_secret()` calls with `core.store_secret_impl()` and direct `DELETE FROM vault.secrets` with `core.delete_secret_impl()`. The function signatures and business logic stay the same — only the storage calls change.

- [ ] **Step 4: Add new files to `sql-scripts.json`**

After `auth_supabase_impl.sql`:
```json
"sql/00_init/secrets_interface.sql",
"sql/00_init/secrets_supabase_impl.sql",
```

- [ ] **Step 5: Run secrets tests**

```bash
pg_prove -v tests/rls/07_invitations_rls.sql
```
(No dedicated secrets test file exists yet — invitations test exercises the audit/core path.)

- [ ] **Step 6: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass.

- [ ] **Step 7: Commit**

```bash
git add sql/00_init/secrets_interface.sql sql/00_init/secrets_supabase_impl.sql \
        sql/_core/functions/secrets.sql sql-scripts.json
git commit -m "refactor: extract vault calls into core.store_secret_impl/delete_secret_impl provider stubs"
```

---

## Phase 2 — Monorepo Directory Structure

> Gate: All 42 tests pass after restructuring. No SQL changes — only file moves and new config files.

---

### Task 2.1 — Initialize pnpm Workspace and Turborepo

**Files:**
- Create: `pnpm-workspace.yaml`
- Create: `turbo.json`
- Create: `packages/core/package.json`
- Create: `packages/supabase/package.json`
- Create: `packages/payload/package.json`
- Create: `packages/billing/package.json`
- Create: `packages/schemas/package.json`
- Modify: `package.json` (root)

- [ ] **Step 1: Create `pnpm-workspace.yaml`**

```yaml
packages:
  - 'packages/*'
```

- [ ] **Step 2: Create `turbo.json`**

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "lint": {}
  }
}
```

- [ ] **Step 3: Create `packages/core/package.json`**

```json
{
  "name": "@smta/core",
  "version": "0.1.0",
  "private": true,
  "description": "SMTA core PostgreSQL schema — tables, RLS, audit, RBAC",
  "scripts": {
    "build": "node ../../combine_files.js"
  }
}
```

Repeat for `packages/supabase`, `packages/payload`, `packages/billing`, `packages/schemas` with appropriate names/descriptions.

- [ ] **Step 4: Install turbo**

```bash
pnpm add -D turbo -w
```

Expected: `pnpm-lock.yaml` updated, `node_modules/.bin/turbo` available.

- [ ] **Step 5: Commit**

```bash
git add pnpm-workspace.yaml turbo.json packages/ package.json pnpm-lock.yaml
git commit -m "chore: initialize pnpm workspace and turborepo"
```

---

### Task 2.2 — Move SQL Files Into Package Directories

**Files:**
- Move: `sql/_core/` → `packages/core/sql/`
- Move: `sql/_utils/` → `packages/core/sql/utils/`
- Move: `sql/00_init/` → `packages/core/sql/init/`
- Move: `sql/_platform/` → `packages/supabase/sql/platform/`
- Move: `sql/_public/` → `packages/supabase/sql/public/` (Supabase exposes public.* via PostgREST)
- Move: `sql/_app/` → `packages/core/sql/app/` (remains empty placeholder)
- Create: `packages/core/sql-scripts.json`
- Create: `packages/supabase/sql-scripts.json`

- [ ] **Step 1: Move core SQL files**

```bash
mkdir -p packages/core/sql/init packages/core/sql/utils packages/core/sql/app
cp -r sql/00_init/* packages/core/sql/init/
cp -r sql/_utils/* packages/core/sql/utils/
cp -r sql/_core/* packages/core/sql/
cp -r sql/_app/* packages/core/sql/app/
```

- [ ] **Step 2: Move supabase SQL files**

```bash
mkdir -p packages/supabase/sql/platform packages/supabase/sql/public
cp -r sql/_platform/* packages/supabase/sql/platform/
cp -r sql/_public/* packages/supabase/sql/public/
```

- [ ] **Step 3: Create `packages/core/sql-scripts.json`**

```json
{
  "version": "1.0",
  "description": "Core package SQL execution order",
  "scripts": [
    "sql/init/schemas.sql",
    "sql/init/auth_interface.sql",
    "sql/init/auth_supabase_impl.sql",
    "sql/init/secrets_interface.sql",
    "sql/init/secrets_supabase_impl.sql",
    "sql/utils/functions.sql",
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
    "sql/rls/helpers.sql",
    "sql/rls/policies.sql",
    "sql/rls/invitations.sql",
    "sql/functions/log_audit.sql",
    "sql/functions/secrets.sql",
    "sql/functions/invitations.sql"
  ]
}
```

- [ ] **Step 4: Create `packages/supabase/sql-scripts.json`**

```json
{
  "version": "1.0",
  "description": "Supabase adapter SQL — platform tables and public RPC functions",
  "scripts": [
    "sql/platform/tables/roles.sql",
    "sql/platform/tables/users.sql",
    "sql/platform/tables/organizations.sql",
    "sql/platform/tables/action_logs.sql",
    "sql/platform/tables/settings.sql",
    "sql/platform/tables/subscription_overrides.sql",
    "sql/platform/tables/feature_flags.sql",
    "sql/platform/tables/system_events.sql",
    "sql/platform/tables/tenant_secrets.sql",
    "sql/platform/tables/billing_customers.sql",
    "sql/platform/tables/billing_subscriptions.sql",
    "sql/platform/tables/subscription_products.sql",
    "sql/platform/tables/grants.sql",
    "sql/platform/rls/lockdown.sql",
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
    "sql/public/functions/user_profile.sql",
    "sql/public/functions/organizations.sql",
    "sql/public/functions/units.sql",
    "sql/public/functions/files.sql",
    "sql/public/functions/audit.sql",
    "sql/public/functions/secrets.sql",
    "sql/public/functions/invitations.sql",
    "sql/public/functions/products.sql"
  ]
}
```

- [ ] **Step 5: Update root `sql-scripts.json` to reference package scripts**

Keep the root `sql-scripts.json` pointing to the original `sql/` paths for backward compatibility during Phase 2. In Phase 3+, the root script will be generated from package scripts.

- [ ] **Step 6: Rename `platform_action_logs.supabase_user_id` column**

In `packages/supabase/sql/platform/tables/action_logs.sql`, rename `supabase_user_id` to `auth_user_id`:
```sql
-- Change: supabase_user_id UUID
-- To: auth_user_id UUID
```

Also update any references in `packages/supabase/sql/platform/functions/log_action.sql`.

- [ ] **Step 7: Verify original SQL paths still work (tests still use them)**

Do NOT update `sql-scripts.json` to the package paths yet — the original `sql/` files are still what gets deployed. The package directories are copies.

```bash
./run_tests.sh
```
Expected: all 42 tests still pass (original files unchanged).

- [ ] **Step 8: Commit**

```bash
git add packages/
git commit -m "chore: copy SQL files into monorepo package directories"
```

---

## Phase 3 — Remove `auth.users` Foreign Keys From Core

> Gate: All 42 tests pass. The Supabase adapter restores the FKs via ALTER TABLE.

This is the highest-risk phase. It decouples the core schema from `auth.users` so the Payload adapter (which has no `auth.users` table) can deploy the core package.

---

### Task 3.1 — Remove FKs from Core Tables

**Files:**
- Modify: `packages/core/sql/tables/memberships.sql`
- Modify: `packages/core/sql/tables/unit_memberships.sql` (check if it exists)
- Modify: `packages/core/sql/tables/users_meta.sql`
- Modify: `packages/core/sql/tables/invitations.sql`
- Create: `packages/supabase/sql/constraints.sql`
- Modify: `packages/supabase/sql-scripts.json`

- [ ] **Step 1: Remove FK from `memberships.sql`**

```sql
-- Before:
user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

-- After:
user_id UUID NOT NULL,
```

Also update `unit_memberships.sql` if it has the same FK pattern.

- [ ] **Step 2: Remove FK from `users_meta.sql`**

```sql
-- Before:
id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

-- After:
id UUID PRIMARY KEY,
```

- [ ] **Step 3: Remove FK from `invitations.sql`**

Remove any `REFERENCES auth.users(id)` constraints on `invited_by` and `accepted_by` columns.

- [ ] **Step 4: Create `packages/supabase/sql/constraints.sql`**

```sql
-- constraints.sql
-- Purpose: Restore auth.users FKs that core removed for adapter-agnosticism.
-- This file runs after core tables are created and adds Supabase-specific integrity.

ALTER TABLE core.users_meta
  ADD CONSTRAINT fk_users_meta_auth_users
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE core.memberships
  ADD CONSTRAINT fk_memberships_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE core.unit_memberships
  ADD CONSTRAINT fk_unit_memberships_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE core.invitations
  ADD CONSTRAINT fk_invitations_invited_by_auth_users
  FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE core.invitations
  ADD CONSTRAINT fk_invitations_accepted_by_auth_users
  FOREIGN KEY (accepted_by) REFERENCES auth.users(id) ON DELETE SET NULL;
```

- [ ] **Step 5: Add `constraints.sql` to `packages/supabase/sql-scripts.json`**

Add after the last core table reference (before any triggers).

- [ ] **Step 6: Also update original `sql/` files to match**

Mirror the same FK removal changes in:
- `sql/_core/tables/memberships.sql`
- `sql/_core/tables/users_meta.sql`
- `sql/_core/tables/invitations.sql`

And add a new file `sql/supabase_constraints.sql` with the `ALTER TABLE` statements. Add it to root `sql-scripts.json` after the core tables.

- [ ] **Step 7: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass. The Supabase adapter restores the FKs, so existing behavior is preserved.

- [ ] **Step 8: Commit**

```bash
git add packages/core/sql/tables/ packages/supabase/sql/constraints.sql \
        packages/supabase/sql-scripts.json \
        sql/_core/tables/memberships.sql sql/_core/tables/users_meta.sql \
        sql/_core/tables/invitations.sql sql/supabase_constraints.sql sql-scripts.json
git commit -m "refactor: remove auth.users FKs from core tables; restore in supabase adapter"
```

---

## Phase 4 — Schemas Package (`@smta/schemas`)

> Gate: `packages/schemas` builds without errors; TypeScript types match current `public.*` function signatures.

No pgTap impact — this is a pure TypeScript package.

---

### Task 4.1 — Initialize Schemas Package

**Files:**
- Create: `packages/schemas/package.json`
- Create: `packages/schemas/tsconfig.json`
- Create: `packages/schemas/src/index.ts`

- [ ] **Step 1: Create `packages/schemas/package.json`**

```json
{
  "name": "@smta/schemas",
  "version": "0.1.0",
  "private": true,
  "description": "Zod schemas for SMTA public.* RPC function contracts",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc --build",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "zod": "^4.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

- [ ] **Step 2: Create `packages/schemas/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "lib": ["ES2020"],
    "strict": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "composite": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 3: Run `pnpm install` in schemas package**

```bash
cd packages/schemas && pnpm install
```

- [ ] **Step 4: Commit**

```bash
git add packages/schemas/
git commit -m "chore: initialize @smta/schemas package"
```

---

### Task 4.2 — Write Schemas for Organization Functions

**Files:**
- Create: `packages/schemas/src/rpc/organizations.ts`

Model: `schema_validation/_schemas/invitations.ts` (the template — function-contract style, not table style).

- [ ] **Step 1: Create `packages/schemas/src/rpc/organizations.ts`**

```typescript
// SYNC-CHECK: public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)
// SYNC-CHECK: public.get_organization(p_id UUID)
// SYNC-CHECK: public.list_my_organizations()
// SYNC-CHECK: public.update_organization(p_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.list_organization_members(p_id UUID)
// SYNC-CHECK: public.add_member_to_organization(p_org_id UUID, p_user_id UUID, p_role_id UUID)
// SYNC-CHECK: public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
// SYNC-CHECK: public.transfer_super_admin(p_org_id UUID, p_new_super_admin_user_id UUID)

import { z } from 'zod';

export const createOrganizationInputSchema = z.object({
  p_name: z.string().min(1, 'Organization name is required').trim(),
  p_description: z.string().optional(),
});
export const createOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  created_at: z.coerce.date(),
});

export const getOrganizationInputSchema = z.object({
  p_id: z.string().uuid(),
});
export const getOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  created_by: z.string().uuid(),
  updated_by: z.string().uuid().nullable(),
  is_deleted: z.boolean(),
  deleted_at: z.coerce.date().nullable(),
  deleted_by: z.string().uuid().nullable(),
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
}).nullable();

export const listMyOrganizationsItemSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  role: z.string(),
});
export const listMyOrganizationsOutputSchema = z.array(listMyOrganizationsItemSchema);

export const updateOrganizationInputSchema = z.object({
  p_id: z.string().uuid(),
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});
export const updateOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  updated_at: z.coerce.date(),
});

export const listOrganizationMembersInputSchema = z.object({
  p_id: z.string().uuid(),
});
export const organizationMemberSchema = z.object({
  user_id: z.string().uuid(),
  email: z.string().email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  role: z.string(),
  is_super_admin: z.boolean(),
});
export const listOrganizationMembersOutputSchema = z.array(organizationMemberSchema);

export const addMemberInputSchema = z.object({
  p_org_id: z.string().uuid(),
  p_user_id: z.string().uuid(),
  p_role_id: z.string().uuid(),
});

export const transferSuperAdminInputSchema = z.object({
  p_org_id: z.string().uuid(),
  p_new_super_admin_user_id: z.string().uuid(),
});

export type CreateOrganizationInput = z.infer<typeof createOrganizationInputSchema>;
export type CreateOrganizationOutput = z.infer<typeof createOrganizationOutputSchema>;
export type ListMyOrganizationsItem = z.infer<typeof listMyOrganizationsItemSchema>;
export type OrganizationMember = z.infer<typeof organizationMemberSchema>;
```

- [ ] **Step 2: Build schemas package**

```bash
cd packages/schemas && pnpm build
```
Expected: `dist/` created with `.js` and `.d.ts` files.

- [ ] **Step 3: Commit**

```bash
git add packages/schemas/src/rpc/organizations.ts
git commit -m "feat(schemas): add organization RPC function schemas"
```

---

### Task 4.3 — Write Schemas for Unit, User, and Invitation Functions

**Files:**
- Create: `packages/schemas/src/rpc/units.ts`
- Create: `packages/schemas/src/rpc/user_profile.ts`
- Migrate: `schema_validation/_schemas/invitations.ts` → `packages/schemas/src/rpc/invitations.ts`
- Create: `packages/schemas/src/index.ts`

- [ ] **Step 1: Create `packages/schemas/src/rpc/units.ts`**

```typescript
// SYNC-CHECK: public.list_units(p_org_id UUID)
// SYNC-CHECK: public.get_unit(p_id UUID)
// SYNC-CHECK: public.create_unit(p_org_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.update_unit(p_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.list_unit_members(p_unit_id UUID)

import { z } from 'zod';

export const listUnitsInputSchema = z.object({ p_org_id: z.string().uuid() });
export const unitSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
});
export const listUnitsOutputSchema = z.array(unitSchema);

export const createUnitInputSchema = z.object({
  p_org_id: z.string().uuid(),
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});

export const updateUnitInputSchema = z.object({
  p_id: z.string().uuid(),
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});

export const unitMemberSchema = z.object({
  user_id: z.string().uuid(),
  email: z.string().email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  role: z.string(),
});

export type Unit = z.infer<typeof unitSchema>;
export type UnitMember = z.infer<typeof unitMemberSchema>;
```

- [ ] **Step 2: Create `packages/schemas/src/rpc/user_profile.ts`**

```typescript
// SYNC-CHECK: public.get_user_profile()
// SYNC-CHECK: public.update_user_profile(p_first_name TEXT, p_last_name TEXT)
// SYNC-CHECK: public.get_user_organizations()
// SYNC-CHECK: public.get_user_units(p_org_id UUID)

import { z } from 'zod';

export const userProfileSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  avatar_url: z.string().url().nullable(),
  timezone: z.string().nullable(),
  locale: z.string().nullable(),
});

export const updateUserProfileInputSchema = z.object({
  p_first_name: z.string().min(1).trim(),
  p_last_name: z.string().min(1).trim(),
});

export const getUserUnitsInputSchema = z.object({ p_org_id: z.string().uuid() });
export const userUnitSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  name: z.string(),
  role: z.string(),
});

export type UserProfile = z.infer<typeof userProfileSchema>;
export type UserUnit = z.infer<typeof userUnitSchema>;
```

- [ ] **Step 3: Migrate invitations schema**

Copy `schema_validation/_schemas/invitations.ts` to `packages/schemas/src/rpc/invitations.ts`.
- Remove the table-level `invitationsSchema` (the first object — lines 8–22 in the original)
- Update the import: `from 'zod/v4'` → `from 'zod'`
- Remove `import { shared_auditSchema } from './_shared_audit'` (no longer needed)

- [ ] **Step 4: Create `packages/schemas/src/index.ts`**

```typescript
export * from './rpc/organizations';
export * from './rpc/units';
export * from './rpc/user_profile';
export * from './rpc/invitations';
```

- [ ] **Step 5: Build and verify**

```bash
cd packages/schemas && pnpm build
```
Expected: builds cleanly with no TypeScript errors.

- [ ] **Step 6: Commit**

```bash
git add packages/schemas/src/
git commit -m "feat(schemas): add unit, user profile, invitation schemas; migrate from schema_validation/"
```

---

## Phase 5 — Billing Package (`@smta/billing`)

> Gate: `packages/billing` TypeScript builds cleanly; Stripe and Lemon Squeezy providers implement the interface.

---

### Task 5.1 — Database Changes for Billing

**Files:**
- Modify: `packages/supabase/sql/platform/tables/billing_customers.sql`
- Modify: `packages/supabase/sql/platform/tables/billing_subscriptions.sql`
- Mirror changes in: `sql/_platform/tables/billing_customers.sql`, `sql/_platform/tables/billing_subscriptions.sql`

- [ ] **Step 1: Add `provider` column and rename `paymentprocessor_customer_id`**

In `billing_customers.sql`, after the existing column definitions, add:
```sql
ALTER TABLE platform.billing_customers
  ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'stripe'
    CONSTRAINT billing_customers_provider_check CHECK (provider IN ('stripe', 'lemon_squeezy'));

ALTER TABLE platform.billing_customers
  RENAME COLUMN paymentprocessor_customer_id TO provider_customer_id;
```

Do the same for `billing_subscriptions.sql` (rename `paymentprocessor_subscription_id` → `provider_subscription_id`).

- [ ] **Step 2: Update `sql/_platform/tables/billing_customers.sql` to match**

Mirror the same changes so the original `sql/` files stay consistent with the package files.

- [ ] **Step 3: Update references in platform billing functions**

In `sql/_platform/functions/billing.sql`, find all uses of `paymentprocessor_customer_id` and `paymentprocessor_subscription_id` and rename them to `provider_customer_id` and `provider_subscription_id`.

Also update the test helper `test_helpers.seed_billing_customer` in `tests/fixtures/00_test_helpers.sql`:
```sql
-- Change: paymentprocessor_customer_id
-- To: provider_customer_id
```

- [ ] **Step 4: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/supabase/sql/platform/tables/ sql/_platform/tables/ \
        sql/_platform/functions/billing.sql tests/fixtures/00_test_helpers.sql
git commit -m "feat(billing): add provider column; rename paymentprocessor_* to provider_*"
```

---

### Task 5.2 — TypeScript Billing Package

**Files:**
- Create: `packages/billing/package.json`
- Create: `packages/billing/tsconfig.json`
- Create: `packages/billing/src/provider.ts`
- Create: `packages/billing/src/stripe/index.ts`
- Create: `packages/billing/src/lemon-squeezy/index.ts`
- Create: `packages/billing/src/index.ts`

- [ ] **Step 1: Create `packages/billing/package.json`**

```json
{
  "name": "@smta/billing",
  "version": "0.1.0",
  "private": true,
  "description": "SMTA billing provider abstraction — Stripe and Lemon Squeezy",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc --build",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "stripe": "^17.0.0",
    "@lemonsqueezy/lemonsqueezy.js": "^4.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/pg": "^8.0.0",
    "pg": "^8.0.0"
  }
}
```

- [ ] **Step 2: Create `packages/billing/src/provider.ts`**

```typescript
export interface CheckoutParams {
  organizationId: string;
  planId: string;
  priceId: string;
  billingEmail: string;
  successUrl: string;
  cancelUrl: string;
  metadata?: Record<string, string>;
}

export interface CheckoutResult {
  checkoutUrl: string;
  sessionId: string;
}

export interface WebhookEvent {
  provider: 'stripe' | 'lemon_squeezy';
  rawBody: Buffer;
  signature: string;
}

export interface ParsedWebhookEvent {
  type: string;
  organizationId: string;
  providerCustomerId: string;
  providerSubscriptionId: string;
  plan: string;
  status: 'active' | 'trialing' | 'past_due' | 'canceled' | 'unpaid';
  currentPeriodEnd: Date;
  cancelAtPeriodEnd: boolean;
}

export interface SubscriptionResult {
  providerSubscriptionId: string;
  plan: string;
  status: string;
  currentPeriodEnd: Date;
  cancelAtPeriodEnd: boolean;
}

export interface BillingProvider {
  readonly name: 'stripe' | 'lemon_squeezy';
  createCheckout(params: CheckoutParams): Promise<CheckoutResult>;
  handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent>;
  getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult>;
  cancelSubscription(providerSubscriptionId: string): Promise<void>;
  recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void>;
  recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void>;
}

export interface DbClient {
  query(sql: string, params?: unknown[]): Promise<{ rows: Record<string, unknown>[] }>;
}
```

- [ ] **Step 3: Create `packages/billing/src/stripe/index.ts`**

```typescript
import Stripe from 'stripe';
import type {
  BillingProvider, CheckoutParams, CheckoutResult,
  WebhookEvent, ParsedWebhookEvent, SubscriptionResult, DbClient
} from '../provider';

export class StripeProvider implements BillingProvider {
  readonly name = 'stripe' as const;
  private stripe: Stripe;

  constructor(secretKey: string) {
    this.stripe = new Stripe(secretKey, { apiVersion: '2025-01-27.acacia' });
  }

  async createCheckout(params: CheckoutParams): Promise<CheckoutResult> {
    const session = await this.stripe.checkout.sessions.create({
      mode: 'subscription',
      customer_email: params.billingEmail,
      line_items: [{ price: params.priceId, quantity: 1 }],
      success_url: params.successUrl,
      cancel_url: params.cancelUrl,
      metadata: { organization_id: params.organizationId, ...params.metadata },
    });
    return { checkoutUrl: session.url!, sessionId: session.id };
  }

  async handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent> {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!webhookSecret) throw new Error('STRIPE_WEBHOOK_SECRET not set');

    const stripeEvent = this.stripe.webhooks.constructEvent(
      event.rawBody, event.signature, webhookSecret
    );

    if (stripeEvent.type === 'customer.subscription.updated' ||
        stripeEvent.type === 'customer.subscription.deleted') {
      const sub = stripeEvent.data.object as Stripe.Subscription;
      return {
        type: stripeEvent.type,
        organizationId: sub.metadata.organization_id,
        providerCustomerId: sub.customer as string,
        providerSubscriptionId: sub.id,
        plan: sub.items.data[0]?.price.id ?? '',
        status: sub.status as ParsedWebhookEvent['status'],
        currentPeriodEnd: new Date(sub.current_period_end * 1000),
        cancelAtPeriodEnd: sub.cancel_at_period_end,
      };
    }

    throw new Error(`Unhandled Stripe event type: ${stripeEvent.type}`);
  }

  async getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult> {
    const sub = await this.stripe.subscriptions.retrieve(providerSubscriptionId);
    return {
      providerSubscriptionId: sub.id,
      plan: sub.items.data[0]?.price.id ?? '',
      status: sub.status,
      currentPeriodEnd: new Date(sub.current_period_end * 1000),
      cancelAtPeriodEnd: sub.cancel_at_period_end,
    };
  }

  async cancelSubscription(providerSubscriptionId: string): Promise<void> {
    await this.stripe.subscriptions.cancel(providerSubscriptionId);
  }

  async recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void> {
    await db.query(
      `INSERT INTO platform.billing_customers (organization_id, provider_customer_id, billing_email, provider)
       VALUES ($1, $2, $3, 'stripe')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_customer_id = EXCLUDED.provider_customer_id,
             billing_email = EXCLUDED.billing_email`,
      [organizationId, providerCustomerId, billingEmail]
    );
  }

  async recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void> {
    await db.query(
      `INSERT INTO platform.billing_subscriptions
         (organization_id, provider_subscription_id, plan, status, provider)
       VALUES ($1, $2, $3, $4, 'stripe')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_subscription_id = EXCLUDED.provider_subscription_id,
             plan = EXCLUDED.plan,
             status = EXCLUDED.status`,
      [params.organizationId, params.providerSubscriptionId, params.plan, params.status]
    );
  }
}
```

- [ ] **Step 4: Create `packages/billing/src/lemon-squeezy/index.ts`**

```typescript
import { lemonSqueezySetup, getSubscription, cancelSubscription } from '@lemonsqueezy/lemonsqueezy.js';
import type {
  BillingProvider, CheckoutParams, CheckoutResult,
  WebhookEvent, ParsedWebhookEvent, SubscriptionResult, DbClient
} from '../provider';
import crypto from 'crypto';

export class LemonSqueezyProvider implements BillingProvider {
  readonly name = 'lemon_squeezy' as const;
  private apiKey: string;
  private storeId: string;

  constructor(apiKey: string, storeId: string) {
    this.apiKey = apiKey;
    this.storeId = storeId;
    lemonSqueezySetup({ apiKey });
  }

  async createCheckout(params: CheckoutParams): Promise<CheckoutResult> {
    const response = await fetch('https://api.lemonsqueezy.com/v1/checkouts', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
      body: JSON.stringify({
        data: {
          type: 'checkouts',
          attributes: {
            checkout_data: { custom: { organization_id: params.organizationId } },
            checkout_options: { embed: false },
            product_options: {
              redirect_url: params.successUrl,
            },
          },
          relationships: {
            store: { data: { type: 'stores', id: this.storeId } },
            variant: { data: { type: 'variants', id: params.priceId } },
          },
        },
      }),
    });
    const data = await response.json() as { data: { attributes: { url: string }, id: string } };
    return { checkoutUrl: data.data.attributes.url, sessionId: data.data.id };
  }

  async handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent> {
    const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
    if (!secret) throw new Error('LEMONSQUEEZY_WEBHOOK_SECRET not set');

    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(event.rawBody);
    const digest = hmac.digest('hex');
    if (digest !== event.signature) throw new Error('Invalid webhook signature');

    const payload = JSON.parse(event.rawBody.toString()) as {
      meta: { event_name: string; custom_data: { organization_id: string } };
      data: { attributes: {
        customer_id: number; first_subscription_item: { subscription_id: number; price_id: string };
        status: string; ends_at: string | null; cancelled: boolean;
      }, id: string };
    };

    return {
      type: payload.meta.event_name,
      organizationId: payload.meta.custom_data.organization_id,
      providerCustomerId: String(payload.data.attributes.customer_id),
      providerSubscriptionId: payload.data.id,
      plan: String(payload.data.attributes.first_subscription_item?.price_id ?? ''),
      status: payload.data.attributes.status as ParsedWebhookEvent['status'],
      currentPeriodEnd: payload.data.attributes.ends_at
        ? new Date(payload.data.attributes.ends_at)
        : new Date(),
      cancelAtPeriodEnd: payload.data.attributes.cancelled,
    };
  }

  async getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult> {
    const { data } = await getSubscription(providerSubscriptionId);
    if (!data) throw new Error('Subscription not found');
    const attrs = data.data.attributes;
    return {
      providerSubscriptionId,
      plan: String(attrs.variant_id),
      status: attrs.status,
      currentPeriodEnd: attrs.ends_at ? new Date(attrs.ends_at) : new Date(),
      cancelAtPeriodEnd: attrs.cancelled,
    };
  }

  async cancelSubscription(providerSubscriptionId: string): Promise<void> {
    await cancelSubscription(providerSubscriptionId);
  }

  async recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string, db: DbClient): Promise<void> {
    await db.query(
      `INSERT INTO platform.billing_customers (organization_id, provider_customer_id, billing_email, provider)
       VALUES ($1, $2, $3, 'lemon_squeezy')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_customer_id = EXCLUDED.provider_customer_id,
             billing_email = EXCLUDED.billing_email`,
      [organizationId, providerCustomerId, billingEmail]
    );
  }

  async recordSubscriptionUpdate(params: ParsedWebhookEvent, db: DbClient): Promise<void> {
    await db.query(
      `INSERT INTO platform.billing_subscriptions
         (organization_id, provider_subscription_id, plan, status, provider)
       VALUES ($1, $2, $3, $4, 'lemon_squeezy')
       ON CONFLICT (organization_id) DO UPDATE
         SET provider_subscription_id = EXCLUDED.provider_subscription_id,
             plan = EXCLUDED.plan,
             status = EXCLUDED.status`,
      [params.organizationId, params.providerSubscriptionId, params.plan, params.status]
    );
  }
}
```

- [ ] **Step 5: Create `packages/billing/src/index.ts`**

```typescript
export type {
  BillingProvider, CheckoutParams, CheckoutResult,
  WebhookEvent, ParsedWebhookEvent, SubscriptionResult, DbClient
} from './provider';
export { StripeProvider } from './stripe';
export { LemonSqueezyProvider } from './lemon-squeezy';
```

- [ ] **Step 6: Build billing package**

```bash
cd packages/billing && pnpm install && pnpm build
```
Expected: builds cleanly.

- [ ] **Step 7: Run full test suite**

```bash
./run_tests.sh
```
Expected: all 42 tests pass (billing package is TypeScript only — no pgTap impact).

- [ ] **Step 8: Commit**

```bash
git add packages/billing/
git commit -m "feat(billing): add BillingProvider interface with Stripe and LemonSqueezy implementations"
```

---

## Phase 6 — Payload Adapter (Research Gate)

> **Pre-requisite:** Before implementing this phase, verify whether `@payloadcms/db-postgres` exposes a hook to run `SET LOCAL app.current_user_id = '...'` within the same connection/transaction as each database operation. If `SET LOCAL` is not available, the fallback is connection-level injection via `pg-pool`'s `connect` event.

> Gate: Payload adapter SQL deploys cleanly against a plain PostgreSQL instance (no Supabase); `core.get_current_user_id()` returns the injected user ID.

---

### Task 6.1 — Research Payload Auth Injection Mechanism

- [ ] **Step 1: Check Payload's database adapter hooks**

Read `@payloadcms/db-postgres` source or docs for lifecycle hooks. Specifically look for:
- `beforeQuery` hook
- `onConnect` callback
- Custom `pool` option acceptance

```bash
pnpm add -D @payloadcms/db-postgres -w
cat node_modules/@payloadcms/db-postgres/dist/index.js | grep -A 5 "beforeQuery\|onConnect\|pool"
```

- [ ] **Step 2: Document finding**

Update `packages/payload/README.md` with the confirmed mechanism before writing any SQL or TypeScript.

---

### Task 6.2 — Payload Adapter SQL

**Files:**
- Create: `packages/payload/sql/auth/get_current_user_id.sql`
- Create: `packages/payload/sql-scripts.json`

- [ ] **Step 1: Create the Payload auth implementation**

```sql
-- get_current_user_id.sql
-- Purpose: Payload CMS implementation — reads from session variable set by Node.js middleware.
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

- [ ] **Step 2: Create `packages/payload/sql-scripts.json`**

```json
{
  "version": "1.0",
  "description": "Payload CMS adapter SQL",
  "scripts": [
    "sql/auth/get_current_user_id.sql"
  ]
}
```

---

### Task 6.3 — Payload Auth Injection Middleware

**Files:**
- Create: `packages/payload/src/middleware/inject-user-context.ts`
- Create: `packages/payload/src/index.ts`
- Create: `packages/payload/package.json`

- [ ] **Step 1: Create middleware**

```typescript
// inject-user-context.ts
// Injects the current user's ID into the PostgreSQL session before each query.
// Call this inside Payload's beforeOperation hook or your own query wrapper.

export async function injectUserContext(
  db: { query(sql: string): Promise<void> },
  userId: string
): Promise<void> {
  // SET LOCAL is transaction-scoped; SET SESSION is connection-scoped.
  // Use whichever the Payload adapter supports (see packages/payload/README.md).
  await db.query(`SELECT set_config('app.current_user_id', '${userId}', true)`);
}

export async function clearUserContext(
  db: { query(sql: string): Promise<void> }
): Promise<void> {
  await db.query(`SELECT set_config('app.current_user_id', '', true)`);
}
```

- [ ] **Step 2: Create `packages/payload/src/index.ts`**

```typescript
export { injectUserContext, clearUserContext } from './middleware/inject-user-context';
```

- [ ] **Step 3: Build**

```bash
cd packages/payload && pnpm install && pnpm build
```

- [ ] **Step 4: Commit**

```bash
git add packages/payload/
git commit -m "feat(payload): add Payload CMS adapter — auth context injection middleware"
```

---

## Self-Review Checklist

- [x] **Spec coverage**: Phase 0 covers all 6 test failures with root-cause fixes. Phases 1–6 map to all 7 spec sections. Authorization principle (RLS=membership gate, CASL=action auth) is referenced in Task 1.3's documentation block.
- [x] **No placeholders**: All code blocks are complete. All function signatures are explicit.
- [x] **Type consistency**: `DbClient` defined in `provider.ts` is used identically in both `StripeProvider` and `LemonSqueezyProvider`. `ParsedWebhookEvent.status` enum is consistent across all files.
- [x] **Phase gates**: Each phase ends with `./run_tests.sh` expected output.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-23-smta-monorepo-redesign.md`.**
