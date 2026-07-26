# Role Labels and Invitation Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `role_label` column to the eight SQL functions that project a role to a user-facing surface, and expose invitation cancel/resend through the better-auth adapter.

**Architecture:** Purely additive SQL change — ten function definitions gain `r.description AS role_label` alongside the existing role identifier, which every adapter passes through for free. Two new better-auth endpoints wrap the already-existing `public.cancel_invitation` and `public.resend_invitation`. Six zod objects in `@smta/schemas` gain the new key.

**Tech Stack:** PostgreSQL 18 + plpgsql, pgTap (via `pg_prove`), TypeScript, zod v4, better-auth, pnpm workspaces, Changesets.

**Spec:** `docs/superpowers/specs/2026-07-26-role-labels-and-invitation-management-design.md`

**Branch:** `feat/invitation-role-labels-and-management` (already created, already holds the spec commit). Do not merge. Do not push.

## Global Constraints

- **Append, never rename.** `role_label` is added *alongside* the existing column. The existing `role` vs `role_name` inconsistency is left exactly as-is. Renaming any existing column is out of scope and is a breaking change.
- **Emit the label raw: `r.description AS role_label`. No `COALESCE`.** `core.roles.description` is nullable and NULL is a meaningful state.
- **`role_label` goes immediately after the role identifier column**, not at the end of the return table.
- **`CREATE OR REPLACE` cannot change a return type.** Every function whose `RETURNS TABLE` changes needs `DROP FUNCTION IF EXISTS <signature>;` inline immediately above its `CREATE OR REPLACE`. Drop signatures omit `DEFAULT` clauses.
- **Delegating functions must move in lockstep.** `public.get_user_organizations` is `SELECT * FROM public.list_my_organizations()`; `public.list_invitations` and `public.get_invitation_details` are `SELECT * FROM core.*`. A mismatch fails at *call* time, not deploy time — the deploy will look clean.
- **Do not touch** `public.get_user_role`, `public.get_user_permissions`, `public.get_user_unit_permissions`, or `public.get_organization`. The spec explains why for each.
- **Do not reorder `packages/core/sql-scripts.json`.** `user_profile.sql` loading before `organizations.sql` is fine; plpgsql does not resolve function bodies at creation time.
- **`packages/core/sql/public/grants.sql` needs no change.** `DROP FUNCTION` discards a function's grants, but none of the ten appears in that file — they all ride the default `PUBLIC EXECUTE` grant, which `CREATE` re-establishes. Only the explicitly-revoked admin functions would have been at risk, and none is in scope. Do not add grant statements for these functions.
- **Built output is committed in this repo.** `packages/schemas/dist/`, `packages/better-auth/dist/`, and both `tsconfig.tsbuildinfo` files are tracked in git. Rebuild and commit them alongside the source change, not as a separate cleanup.
- **The better-auth handler parameter must be named `invitationId`.** `tests/adapters/04_endpoint_arg_order.sh` maps JS identifiers to SQL parameter names and already carries `invitationId → p_invitation_id p_id`. Any other name fails the guard.
- **Commit messages:** conventional-commit prefixes (`feat:`, `docs:`, `test:`). **No `Co-Authored-By` trailer.**
- **Never claim a test passes without running it and reading the output.**

## Running the tests

The suite needs a live PostgreSQL database with the SMTA schema loaded.

```bash
./scripts/run_tests.sh          # full suite: adapter guards + pg_prove
```

Connection comes from `DB_URL` or the standard `PG*` environment variables. If no database is reachable, **say so plainly and stop** — do not mark test steps complete.

Baseline before this work: **508 pgTap assertions passing**. After Task 4: **522**.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `packages/core/sql/functions/invitations.sql` | Modify (2 fns) | `core.list_organization_invitations`, `core.get_invitation_by_token` |
| `packages/core/sql/public/functions/invitations.sql` | Modify (2 fns) | Public wrappers, mirror core exactly |
| `packages/core/sql/public/functions/organizations.sql` | Modify (2 fns) | `list_my_organizations`, `list_organization_members` |
| `packages/core/sql/public/functions/units.sql` | Modify (2 fns) | `list_my_units`, `list_unit_members` |
| `packages/core/sql/public/functions/user_profile.sql` | Modify (2 fns) | `get_user_organizations`, `get_user_units` |
| `tests/functions/06_role_labels.sql` | **Create** | Single home for the label contract, all eight functions |
| `scripts/run_tests.sh` | Modify (1 line) | Register the new test file |
| `packages/schemas/src/rpc/invitations.ts` | Modify (2 objects) | `invitationListItemSchema`, `invitationDetailsSchema` |
| `packages/schemas/src/rpc/organizations.ts` | Modify (2 objects) | `listMyOrganizationsItemSchema`, `organizationMemberSchema` |
| `packages/schemas/src/rpc/units.ts` | Modify (1 object) | `unitMemberSchema` |
| `packages/schemas/src/rpc/user_profile.ts` | Modify (1 object) | `userUnitSchema` |
| `packages/better-auth/src/plugin/endpoints.ts` | Modify | `cancelInvitation`, `resendInvitation` handlers |
| `packages/better-auth/src/plugin/index.ts` | Modify | `smtaCancelInvitation`, `smtaResendInvitation` endpoints |
| `packages/better-auth/dist/**` | Regenerate | Built output is committed in this repo |
| `apps/docs/src/content/docs/rpc-reference/{invitations,organizations,units,user-profile}.mdx` | Modify | Signature blocks |
| `apps/docs/src/content/docs/adapters/better-auth.mdx` | Modify | Endpoint table |
| `.changeset/role-labels-and-invitation-management.md` | **Create** | Minor bump across the fixed group |

## Test fixture reference

Used by every assertion in `tests/functions/06_role_labels.sql`. Values are from `tests/fixtures/01_roles.sql` and `tests/fixtures/03_bella_italia.sql`.

**Roles** — `core.roles.name` → `core.roles.description`:

| ID | `name` | `description` |
|---|---|---|
| `00000000-0000-0000-0000-000000000001` | `super_admin` | `Organization owner with full administrative access` |
| `00000000-0000-0000-0000-000000000002` | `manager` | `Location manager with administrative access to assigned units` |
| `00000000-0000-0000-0000-000000000003` | `team` | `Team member with read access and limited write access` |

**Org:** Bella Italia Restaurant Group = `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`
**Unit:** Downtown = `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01`

**People:** `maria@test.bellaitalia.com` is `super_admin` at org level. `carlos@test.bellaitalia.com` is `manager` at org level and `manager` at Downtown. `sam@test.bellaitalia.com` is `team` at org level and `team` at Downtown.

Set the acting user with `SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('<email>'));`.

---

### Task 1: `role_label` on the invitation reads

Two `core` functions and their two `public` wrappers. This task also creates the test file and registers it with the runner.

**Files:**
- Create: `tests/functions/06_role_labels.sql`
- Modify: `scripts/run_tests.sh` (one line, after `tests/functions/05_permissions_functions.sql \`)
- Modify: `packages/core/sql/functions/invitations.sql:392-438` (`core.list_organization_invitations`), `:445-476` (`core.get_invitation_by_token`)
- Modify: `packages/core/sql/public/functions/invitations.sql:153-171` (`public.list_invitations`), `:190-206` (`public.get_invitation_details`)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `core.list_organization_invitations(UUID, TEXT)` and `public.list_invitations(UUID, TEXT)` return `(id, email, organization_id, unit_id, role_name, role_label, invited_by_email, status, expires_at, created_at)`. `core.get_invitation_by_token(TEXT)` and `public.get_invitation_details(TEXT)` return `(id, email, organization_name, unit_name, role_name, role_label, invited_by_name, expires_at, status)`. `tests/functions/06_role_labels.sql` exists with `SELECT plan(4)`; Tasks 2–4 grow that number.

- [ ] **Step 1: Write the failing test**

Create `tests/functions/06_role_labels.sql`:

```sql
-- 06_role_labels.sql
-- Purpose: Every function that projects a role to a user-facing surface must
-- return the role's display label (core.roles.description) alongside the stable
-- identifier (core.roles.name).
--
-- WHY this file exists: consumers cannot derive the label from the identifier.
-- super_admin's label is "Owner"; de-slugifying yields "Super Admin", a role
-- that does not exist in the product — and it is the highest-privilege role in
-- the system. Any consumer that derives rather than reads gets that one wrong.
--
-- One file rather than assertions scattered across five others, so the label
-- contract has a single home and a ninth function has an obvious place to land.

BEGIN;

SELECT plan(4);

-- ========================================
-- SETUP: an invitation carrying the manager role
-- ========================================
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

DO $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT * INTO v_result FROM public.create_invitation(
    'labeltest@example.com',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid  -- manager
  );
  PERFORM set_config('test.label_invitation_token', v_result.token, false);
END $$;

-- ========================================
-- public.list_invitations
-- ========================================
SELECT is(
  (SELECT role_label FROM public.list_invitations(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'labeltest@example.com'),
  'Location manager with administrative access to assigned units',
  'list_invitations returns the role label'
);

-- The identifier must survive unchanged — this is an additive column, not a
-- rename. Consumers key behaviour on the identifier.
SELECT is(
  (SELECT role_name FROM public.list_invitations(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'labeltest@example.com'),
  'manager',
  'list_invitations still returns the role identifier'
);

-- ========================================
-- public.get_invitation_details
-- ========================================
SELECT is(
  (SELECT role_label FROM public.get_invitation_details(
     current_setting('test.label_invitation_token'))),
  'Location manager with administrative access to assigned units',
  'get_invitation_details returns the role label'
);

SELECT is(
  (SELECT role_name FROM public.get_invitation_details(
     current_setting('test.label_invitation_token'))),
  'manager',
  'get_invitation_details still returns the role identifier'
);

SELECT * FROM finish();

ROLLBACK;
```

- [ ] **Step 2: Register the test file with the runner**

`scripts/run_tests.sh` lists test files explicitly — it does not glob. Add one line after `tests/functions/05_permissions_functions.sql \`:

```bash
  tests/functions/05_permissions_functions.sql \
  tests/functions/06_role_labels.sql \
  tests/invitations/01_create_invitation.sql \
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: FAIL with `column "role_label" does not exist`.

**What you will actually see:** an uncaught SQL error aborts the enclosing transaction, so the file does not report "2 passed, 2 failed" — it stops at the first `role_label` reference and `pg_prove` reports the whole file as failing. That is the correct red bar. Do not try to make the file limp through the error; the column genuinely does not exist yet.

- [ ] **Step 4: Add `role_label` to the two `core` functions**

In `packages/core/sql/functions/invitations.sql`, replace the `core.list_organization_invitations` definition (currently starting at line 392) so that it is preceded by a drop and returns the new column:

```sql
-- CREATE OR REPLACE cannot change a return type, so the old signature must go
-- first. Drop signatures omit DEFAULT clauses.
DROP FUNCTION IF EXISTS core.list_organization_invitations(UUID, TEXT);

CREATE OR REPLACE FUNCTION core.list_organization_invitations(
  p_organization_id UUID,
  p_status TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_id UUID,
  unit_id UUID,
  role_name TEXT,
  role_label TEXT,
  invited_by_email TEXT,
  status TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Authorization: Must be a member of the organization.
  -- Checked BEFORE validating p_status so a non-member cannot use the error
  -- message to probe which status values are accepted.
  IF NOT core.is_org_member(p_organization_id) THEN
    RAISE EXCEPTION 'You are not authorized to view invitations for this organization';
  END IF;

  -- Validate the optional status filter (mirrors invitations.valid_status)
  IF p_status IS NOT NULL AND p_status NOT IN ('pending', 'accepted', 'expired', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid status. Must be "pending", "accepted", "expired", or "cancelled".';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.email,
    i.organization_id,
    i.unit_id,
    r.name AS role_name,
    -- Emitted raw, not COALESCEd to r.name: description is nullable and roles
    -- are seeded per deployment, so NULL genuinely means "no label was given".
    -- Falling back to the identifier would render 'super_admin' to an end user.
    r.description AS role_label,
    um.email AS invited_by_email,
    i.status,
    i.expires_at,
    i.created_at
  FROM core.invitations i
  JOIN core.roles r ON r.id = i.role_id
  LEFT JOIN core.users_meta um ON um.id = i.invited_by
  WHERE i.organization_id = p_organization_id
    AND i.is_deleted = false
    AND (p_status IS NULL OR i.status = p_status)
  ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;
```

Then replace the `core.get_invitation_by_token` definition (currently starting at line 445):

```sql
DROP FUNCTION IF EXISTS core.get_invitation_by_token(TEXT);

CREATE OR REPLACE FUNCTION core.get_invitation_by_token(
  p_token TEXT
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_name TEXT,
  unit_name TEXT,
  role_name TEXT,
  role_label TEXT,
  invited_by_name TEXT,
  expires_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.email,
    o.name AS organization_name,
    u.name AS unit_name,
    r.name AS role_name,
    r.description AS role_label,
    COALESCE(um.first_name || ' ' || um.last_name, um.email) AS invited_by_name,
    i.expires_at,
    i.status
  FROM core.invitations i
  JOIN core.organizations o ON o.id = i.organization_id
  LEFT JOIN core.units u ON u.id = i.unit_id
  JOIN core.roles r ON r.id = i.role_id
  LEFT JOIN core.users_meta um ON um.id = i.invited_by
  WHERE i.token = p_token
    AND i.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = core;
```

- [ ] **Step 5: Mirror the change in the two `public` wrappers**

These are `SELECT * FROM core.…`. Their `RETURNS TABLE` must match their delegate's column order exactly or every call raises a structure mismatch at call time.

In `packages/core/sql/public/functions/invitations.sql`, replace `public.list_invitations` (currently starting at line 153):

```sql
DROP FUNCTION IF EXISTS public.list_invitations(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.list_invitations(
  p_organization_id UUID,
  p_status TEXT DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_id UUID,
  unit_id UUID,
  role_name TEXT,
  role_label TEXT,
  invited_by_email TEXT,
  status TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.list_organization_invitations(p_organization_id, p_status);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

And `public.get_invitation_details` (currently starting at line 190) — note this one is `SECURITY DEFINER`, keep it that way:

```sql
DROP FUNCTION IF EXISTS public.get_invitation_details(TEXT);

CREATE OR REPLACE FUNCTION public.get_invitation_details(
  p_token TEXT
) RETURNS TABLE (
  id UUID,
  email TEXT,
  organization_name TEXT,
  unit_name TEXT,
  role_name TEXT,
  role_label TEXT,
  invited_by_name TEXT,
  expires_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM core.get_invitation_by_token(p_token);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, core;
```

Leave the surrounding doc comments in both files intact.

- [ ] **Step 6: Reload the SQL and run the test to verify it passes**

Apply the four changed function definitions to your test database, then:

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: PASS, 4/4.

- [ ] **Step 7: Run the invitation suite to confirm nothing regressed**

Run: `pg_prove -v "$DB_URL" tests/invitations/01_create_invitation.sql tests/invitations/02_accept_invitation.sql tests/invitations/03_manage_invitations.sql tests/rls/07_invitations_rls.sql`
Expected: PASS. Every `SELECT *` against these functions in the existing suite is inside `throws_ok`, which never compares a result set, so an added column breaks nothing.

- [ ] **Step 8: Commit**

```bash
git add packages/core/sql/functions/invitations.sql \
        packages/core/sql/public/functions/invitations.sql \
        tests/functions/06_role_labels.sql \
        scripts/run_tests.sh
git commit -m "feat(core): return role_label from the invitation read functions

core.list_organization_invitations and core.get_invitation_by_token already
join core.roles for r.name, so returning r.description costs nothing. Consumers
were rendering raw identifiers to end users — an invitation landing page read
'invited you as general_manager'.

The label is appended, not swapped in: consumers key behaviour on the stable
identifier and keep getting it. Emitted raw rather than COALESCEd to r.name,
because description is nullable and roles are seeded per deployment; falling
back to the identifier would render 'super_admin' to an end user in the one
case nobody tests.

CREATE OR REPLACE cannot change a return type, so each definition is preceded
by DROP FUNCTION IF EXISTS, matching the convention already used for
public.create_organization and platform.create_platform_user.

The two public wrappers are SELECT * FROM core.*, so their RETURNS TABLE moves
in lockstep — a mismatch there fails at call time, not deploy time.

New test file tests/functions/06_role_labels.sql, registered in run_tests.sh
(which lists files explicitly rather than globbing). It will grow to cover all
eight role-projecting functions."
```

---

### Task 2: `role_label` on the organization reads

`public.list_my_organizations`, `public.list_organization_members`, and `public.get_user_organizations` — which delegates to the first and therefore **must** change in the same commit.

**Files:**
- Modify: `tests/functions/06_role_labels.sql` (plan count 4 → 9, add a section)
- Modify: `packages/core/sql/public/functions/organizations.sql:8-25` (`list_my_organizations`), `:57-81` (`list_organization_members`)
- Modify: `packages/core/sql/public/functions/user_profile.sql:74-84` (`get_user_organizations`)

**Interfaces:**
- Consumes: the test file and runner registration from Task 1.
- Produces: `public.list_my_organizations()` and `public.get_user_organizations()` return `(id, name, description, role, role_label)`. `public.list_organization_members(UUID)` returns `(user_id, email, first_name, last_name, role, role_label, is_super_admin)`.

- [ ] **Step 1: Write the failing test**

In `tests/functions/06_role_labels.sql`, change `SELECT plan(4);` to `SELECT plan(9);` and insert this section immediately before `SELECT * FROM finish();`:

```sql
-- ========================================
-- public.list_my_organizations  (acting user: maria, super_admin)
-- ========================================
-- NOTE: `description` here is the ORGANIZATION's description; `role_label` is
-- the ROLE's. Two different columns, distinctly aliased. Do not conflate them.
SELECT is(
  (SELECT role_label FROM public.list_my_organizations()
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
  'Organization owner with full administrative access',
  'list_my_organizations returns the role label'
);

SELECT is(
  (SELECT role FROM public.list_my_organizations()
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
  'super_admin',
  'list_my_organizations still returns the role identifier'
);

-- ========================================
-- public.get_user_organizations
-- ========================================
-- This function is literally RETURN QUERY SELECT * FROM list_my_organizations().
-- If its RETURNS TABLE did not gain role_label in the same position, this call
-- raises a structure mismatch. That failure happens at CALL time, not deploy
-- time — which is exactly why this assertion exists.
SELECT is(
  (SELECT role_label FROM public.get_user_organizations()
   WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
  'Organization owner with full administrative access',
  'get_user_organizations returns the role label through its delegate'
);

-- ========================================
-- public.list_organization_members
-- ========================================
-- The most important of the eight: this is the function that renders an
-- organisation's Owner. super_admin -> "Owner" is precisely the mapping no
-- consumer can derive, and invitations can never carry super_admin at all.
SELECT is(
  (SELECT role_label FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'maria@test.bellaitalia.com'),
  'Organization owner with full administrative access',
  'list_organization_members returns the label for the org owner'
);

SELECT is(
  (SELECT role_label FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'carlos@test.bellaitalia.com'),
  'Location manager with administrative access to assigned units',
  'list_organization_members returns the label for a manager'
);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: FAIL with `column "role_label" does not exist`. As in Task 1, the uncaught error aborts the transaction, so the file fails as a whole rather than reporting a per-assertion split — including the four assertions from Task 1 that passed a moment ago. That is expected.

- [ ] **Step 3: Add `role_label` to the two organization functions**

In `packages/core/sql/public/functions/organizations.sql`, replace `public.list_my_organizations` (currently starting at line 8):

```sql
DROP FUNCTION IF EXISTS public.list_my_organizations();

CREATE OR REPLACE FUNCTION public.list_my_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT,
  role_label TEXT
) AS $$
BEGIN
  RETURN QUERY
  -- o.description is the organization's; r.description is the role's label.
  SELECT o.id, o.name, o.description, r.name AS role, r.description AS role_label
  FROM core.organizations o
  JOIN core.memberships m ON m.organization_id = o.id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = core.get_current_user_id()
    AND m.is_deleted = false
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

Then replace `public.list_organization_members` (currently starting at line 57):

```sql
DROP FUNCTION IF EXISTS public.list_organization_members(UUID);

CREATE OR REPLACE FUNCTION public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  role_label TEXT,
  is_super_admin BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT m.user_id,
         um.email,
         um.first_name,
         um.last_name,
         r.name AS role,
         r.description AS role_label,
         m.is_super_admin
  FROM core.memberships m
  JOIN core.users_meta um ON um.id = m.user_id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.organization_id = p_id
    AND m.is_deleted = false
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

Leave `public.get_organization` (lines 31-51) untouched — it projects no role.

- [ ] **Step 4: Update the delegate in `user_profile.sql`**

In `packages/core/sql/public/functions/user_profile.sql`, replace `public.get_user_organizations` (currently starting at line 74):

```sql
DROP FUNCTION IF EXISTS public.get_user_organizations();

CREATE OR REPLACE FUNCTION public.get_user_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT,
  role_label TEXT
) AS $$
BEGIN
  -- SELECT * from the delegate: this RETURNS TABLE must match
  -- public.list_my_organizations() column-for-column, in order.
  RETURN QUERY SELECT * FROM public.list_my_organizations();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

Do **not** reorder `packages/core/sql-scripts.json`. `user_profile.sql` loads before `organizations.sql`, which is fine — plpgsql does not resolve function bodies at creation time.

- [ ] **Step 5: Reload the SQL and run the test to verify it passes**

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: PASS, 9/9.

- [ ] **Step 6: Run the organization and membership suites**

Run: `pg_prove -v "$DB_URL" tests/functions/01_organization_functions.sql tests/functions/04_user_functions.sql tests/membership/04_organization_membership.sql tests/edge_cases/01_multi_org_user.sql tests/edge_cases/04_role_scenarios.sql`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/core/sql/public/functions/organizations.sql \
        packages/core/sql/public/functions/user_profile.sql \
        tests/functions/06_role_labels.sql
git commit -m "feat(core): return role_label from the organization read functions

list_organization_members is the most important of the eight: it is the one
that renders an organisation's Owner, and super_admin -> 'Owner' is precisely
the mapping no consumer can derive. Invitations can never carry super_admin at
all (create_invitation rejects it; ownership transfer is transfer_super_admin),
so a member roster mislabels the owner to everyone, every time, while the
invitation functions can only ever mislabel the three lesser roles.

get_user_organizations is RETURN QUERY SELECT * FROM list_my_organizations(),
so its RETURNS TABLE moves in the same commit. A mismatch there raises at call
time, not deploy time, which would make a broken deploy look clean. There is an
explicit assertion for the delegate specifically.

In list_my_organizations, o.description is the organization's and r.description
is the role's label — two different columns, distinctly aliased.

get_organization is untouched: it projects no role."
```

---

### Task 3: `role_label` on the unit reads

`public.list_my_units`, `public.list_unit_members`, and `public.get_user_units`. Unlike Task 2, `get_user_units` duplicates the query rather than delegating, but it belongs in this commit because it is unit-shaped.

**Files:**
- Modify: `tests/functions/06_role_labels.sql` (plan count 9 → 12, add a section)
- Modify: `packages/core/sql/public/functions/units.sql:9-26` (`list_my_units`), `:54-75` (`list_unit_members`)
- Modify: `packages/core/sql/public/functions/user_profile.sql:90-108` (`get_user_units`)

**Interfaces:**
- Consumes: the test file from Tasks 1–2.
- Produces: `public.list_my_units()` and `public.get_user_units(UUID)` return `(id, organization_id, name, role, role_label)`. `public.list_unit_members(UUID)` returns `(user_id, email, first_name, last_name, role, role_label)`.

- [ ] **Step 1: Write the failing test**

In `tests/functions/06_role_labels.sql`, change `SELECT plan(9);` to `SELECT plan(12);` and insert this section immediately before `SELECT * FROM finish();`:

```sql
-- ========================================
-- public.list_my_units  (self-scoped: must act as carlos)
-- ========================================
-- list_my_units filters on core.get_current_user_id(), so the acting user has
-- to be the one whose units we assert on. Carlos is manager at Downtown.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('carlos@test.bellaitalia.com'));

SELECT is(
  (SELECT role_label FROM public.list_my_units()
   WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid),
  'Location manager with administrative access to assigned units',
  'list_my_units returns the role label'
);

-- ========================================
-- public.get_user_units
-- ========================================
SELECT is(
  (SELECT role_label FROM public.get_user_units(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid),
  'Location manager with administrative access to assigned units',
  'get_user_units returns the role label'
);

-- ========================================
-- public.list_unit_members
-- ========================================
-- Back to maria: unit_memberships_select allows any org member to read the
-- unit memberships of their org's units, and she is the org owner.
-- Sam is team at Downtown.
SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT role_label FROM public.list_unit_members(
     'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid)
   WHERE email = 'sam@test.bellaitalia.com'),
  'Team member with read access and limited write access',
  'list_unit_members returns the role label'
);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: FAIL with `column "role_label" does not exist`, raised by the first of the three new assertions. The transaction aborts, so the file fails as a whole — same as Tasks 1 and 2.

- [ ] **Step 3: Add `role_label` to the two unit functions**

In `packages/core/sql/public/functions/units.sql`, replace `public.list_my_units` (currently starting at line 9):

```sql
DROP FUNCTION IF EXISTS public.list_my_units();

CREATE OR REPLACE FUNCTION public.list_my_units()
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT,
  role_label TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role, r.description AS role_label
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

Then replace `public.list_unit_members` (currently starting at line 54):

```sql
DROP FUNCTION IF EXISTS public.list_unit_members(UUID);

CREATE OR REPLACE FUNCTION public.list_unit_members(p_unit_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  role_label TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT um.user_id,
         umeta.email,
         umeta.first_name,
         umeta.last_name,
         r.name AS role,
         r.description AS role_label
  FROM core.unit_memberships um
  JOIN core.users_meta umeta ON umeta.id = um.user_id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.unit_id = p_unit_id
    AND um.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

Leave `public.get_unit` and `public.get_user_unit_permissions` untouched.

- [ ] **Step 4: Update `get_user_units` in `user_profile.sql`**

Replace `public.get_user_units` (currently starting at line 90):

```sql
DROP FUNCTION IF EXISTS public.get_user_units(UUID);

CREATE OR REPLACE FUNCTION public.get_user_units(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT,
  role_label TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role, r.description AS role_label
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = core.get_current_user_id()
    AND u.organization_id = p_org_id
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;
```

- [ ] **Step 5: Reload the SQL and run the test to verify it passes**

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: PASS, 12/12.

- [ ] **Step 6: Run the unit and user suites**

Run: `pg_prove -v "$DB_URL" tests/functions/02_unit_functions.sql tests/functions/04_user_functions.sql tests/membership/05_unit_membership.sql`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/core/sql/public/functions/units.sql \
        packages/core/sql/public/functions/user_profile.sql \
        tests/functions/06_role_labels.sql
git commit -m "feat(core): return role_label from the unit read functions

Completes the eight role-projecting surfaces. list_my_units and get_user_units
are self-scoped on core.get_current_user_id(), so their assertions act as
carlos; list_unit_members reads any org member's units, so it acts as maria.

get_user_units duplicates list_my_units' query rather than delegating to it, so
unlike get_user_organizations there is no lockstep hazard here — but it is
unit-shaped and belongs in this commit.

get_unit and get_user_unit_permissions are untouched: the former projects no
role, the latter is machine-facing and feeds a CASL Ability."
```

---

### Task 4: NULL passthrough and identifier-stability guards

The cross-cutting assertions that could not be written until all eight functions existed. These encode the two decisions most likely to be "helpfully" undone by a future contributor.

**Files:**
- Modify: `tests/functions/06_role_labels.sql` (plan count 12 → 14, add a section)

**Interfaces:**
- Consumes: all eight functions from Tasks 1–3.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test**

In `tests/functions/06_role_labels.sql`, change `SELECT plan(12);` to `SELECT plan(14);` and insert this section immediately before `SELECT * FROM finish();`:

```sql
-- ========================================
-- NULL passthrough
-- ========================================
-- core.roles.description is nullable and roles are seeded per deployment, so
-- NULL is a real state meaning "this deployment gave the role no label".
-- The functions must NOT COALESCE it to r.name: doing so would render
-- 'super_admin' to an end user in exactly the case nobody tests, which is the
-- original bug reappearing somewhere harder to find.
--
-- This UPDATE is safe: tests wrap in BEGIN/ROLLBACK, and nothing anywhere
-- asserts an exact core.roles count (only existence and > 0).
SELECT test_helpers.set_service_role();

UPDATE core.roles SET description = NULL WHERE name = 'manager';

SELECT test_helpers.set_auth_user(test_helpers.get_test_user_id('maria@test.bellaitalia.com'));

SELECT is(
  (SELECT role_label FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'carlos@test.bellaitalia.com'),
  NULL,
  'A role with no description yields NULL role_label, not the identifier'
);

-- The identifier must be unaffected by the missing label.
SELECT is(
  (SELECT role FROM public.list_organization_members(
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
   WHERE email = 'carlos@test.bellaitalia.com'),
  'manager',
  'The role identifier is unaffected by a NULL label'
);
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql`
Expected: PASS, 14/14.

These assertions pass immediately — they are regression guards on already-correct behaviour, not new functionality. That is the point: they fail loudly if someone later adds a `COALESCE`.

- [ ] **Step 3: Verify the ROLLBACK actually protects the next test file**

The `UPDATE core.roles` must not leak. Run the new file followed by a file that reads role descriptions:

Run: `pg_prove -v "$DB_URL" tests/functions/06_role_labels.sql tests/membership/01_roles_exist.sql`
Expected: PASS for both. If `01_roles_exist.sql` fails, the transaction wrapper is broken — stop and investigate rather than working around it.

- [ ] **Step 4: Commit**

```bash
git add tests/functions/06_role_labels.sql
git commit -m "test(core): guard the NULL-label and identifier-stability decisions

Two assertions that could only be written once all eight functions existed.
Both pass immediately — they are regression guards on already-correct
behaviour, which is exactly their value.

The NULL guard fails loudly if someone later 'fixes' the nullable label by
COALESCEing it to r.name. That would render 'super_admin' to an end user in
the one case nobody tests, reintroducing the original bug somewhere harder to
find. NULL means 'this deployment gave the role no label' and the consumer
decides the fallback.

The identifier guard fails if someone renames role/role_name while
standardising the two spellings. That is a breaking change for every consumer
selecting by name, and is deliberately out of scope.

The UPDATE is transaction-local; nothing anywhere asserts an exact
core.roles count, only existence and > 0."
```

---

### Task 5: `role_label` in `@smta/schemas`

Six zod objects covering all eight functions — four share a shape.

**Files:**
- Modify: `packages/schemas/src/rpc/invitations.ts:31-52`
- Modify: `packages/schemas/src/rpc/organizations.ts:38-44` and `:60-68`
- Modify: `packages/schemas/src/rpc/units.ts:32-39`
- Modify: `packages/schemas/src/rpc/user_profile.ts:24-30`

**Interfaces:**
- Consumes: the SQL contract from Tasks 1–3.
- Produces: `InvitationDetails`, `InvitationListItem`, `OrganizationMember`, `UserUnit`, and the `listMyOrganizationsItemSchema` / `unitMemberSchema` inferred types all carry `role_label: string | null`.

**Note on verification:** this repo has no JavaScript test runner — every test is pgTap or a bash guard. The contract these schemas mirror is already asserted at the SQL level in Tasks 1–4. Verification here is a successful type-check and build. Do not invent a test harness for this task.

- [ ] **Step 1: Add `role_label` to both invitation schemas**

In `packages/schemas/src/rpc/invitations.ts`, add the key immediately after `role_name` in each object:

```ts
export const invitationDetailsSchema = z.object({
  id: z.uuid(),
  email: z.email(),
  organization_name: z.string(),
  unit_name: z.string().nullable(),
  role_name: z.string(),
  // core.roles.description. Nullable: roles are seeded per deployment, so a
  // deployment may give a role no label. Required (not .optional()) — all
  // @smta/* packages share one Changesets fixed group and always publish at
  // the same version, so a missing key means the SQL was never applied. That
  // should raise at the first call, not render as a blank label in production.
  role_label: z.string().nullable(),
  invited_by_name: z.string(),
  expires_at: z.coerce.date(),
  status: invitationStatusSchema,
});

export const invitationListItemSchema = z.object({
  id: z.uuid(),
  email: z.email(),
  organization_id: z.uuid(),
  unit_id: z.uuid().nullable(),
  role_name: z.string(),
  role_label: z.string().nullable(),
  invited_by_email: z.email(),
  status: invitationStatusSchema,
  expires_at: z.coerce.date(),
  created_at: z.coerce.date(),
});
```

- [ ] **Step 2: Add `role_label` to both organization schemas**

In `packages/schemas/src/rpc/organizations.ts`:

```ts
export const listMyOrganizationsItemSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().nullable(),   // the ORGANIZATION's description
  role: z.string(),
  role_label: z.string().nullable(),    // the ROLE's label
});
```

```ts
export const organizationMemberSchema = z.object({
  user_id: z.uuid(),
  email: z.email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  role: z.string(),
  role_label: z.string().nullable(),
  is_super_admin: z.boolean(),
});
```

`listMyOrganizationsItemSchema` covers both `list_my_organizations` and `get_user_organizations` — they return identical shapes.

- [ ] **Step 3: Add `role_label` to the unit member schema**

In `packages/schemas/src/rpc/units.ts`:

```ts
export const unitMemberSchema = z.object({
  user_id: z.uuid(),
  email: z.email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  role: z.string(),
  role_label: z.string().nullable(),
});
```

Leave `unitSchema` alone — `public.list_units` projects no role.

- [ ] **Step 4: Add `role_label` to the user unit schema**

In `packages/schemas/src/rpc/user_profile.ts`:

```ts
export const userUnitSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  name: z.string(),
  role: z.string(),
  role_label: z.string().nullable(),
});
```

`userUnitSchema` covers both `list_my_units` and `get_user_units`.

The `SYNC-CHECK` header comments in these files list function *parameters*, not return columns, so they need no edit.

- [ ] **Step 5: Type-check and build**

Run: `pnpm --filter @smta/schemas build`
Expected: exit 0, no type errors.

- [ ] **Step 6: Commit**

```bash
git add packages/schemas/src/rpc/invitations.ts \
        packages/schemas/src/rpc/organizations.ts \
        packages/schemas/src/rpc/units.ts \
        packages/schemas/src/rpc/user_profile.ts \
        packages/schemas/dist \
        packages/schemas/tsconfig.tsbuildinfo
git commit -m "feat(schemas): add role_label to the six role-projecting schemas

Six zod objects cover all eight SQL functions, because four share a shape:
listMyOrganizationsItemSchema serves list_my_organizations and
get_user_organizations, and userUnitSchema serves list_my_units and
get_user_units.

Typed required-and-nullable rather than optional. Zod objects strip unknown
keys, so without this the column would arrive from SQL and be silently
discarded for anyone validating through this package. All @smta/* packages
share one Changesets fixed group and always publish at the same version, so a
consumer whose database lacks the column has a deploy error — it should raise a
ZodError naming role_label at the first call rather than render a blank label.
Optional would buy skew tolerance at the cost of a permanent
string | null | undefined that every consumer branches on forever.

unitSchema is untouched: public.list_units projects no role."
```

---

### Task 6: `smtaCancelInvitation` and `smtaResendInvitation`

Gap 2. Both SQL functions already exist, are already authorised, and are already audited — this is adapter wiring only.

**Files:**
- Modify: `packages/better-auth/src/plugin/endpoints.ts` (add two handlers after `listInvitations`, line 87)
- Modify: `packages/better-auth/src/plugin/index.ts` (add two endpoints after `smtaListInvitations`, line 109)
- Regenerate: `packages/better-auth/dist/**`

**Interfaces:**
- Consumes: `withSMTA<T>(pool, userId, fn): Promise<T>` and `callPublicFn(client, fnName, args): Promise<unknown>`, both already in `endpoints.ts`.
- Produces: `handlers.cancelInvitation(userId: string, invitationId: string): Promise<{ success: true }>` and `handlers.resendInvitation(userId: string, invitationId: string): Promise<unknown>`. Routes `POST /smta/invitation/:id/cancel` and `POST /smta/invitation/:id/resend`.

- [ ] **Step 1: Record the current arg-order guard baseline**

The guard is the real-database integration test for these endpoints — it greps every `callPublicFn` call site and validates it positionally against live `pg_proc`. A mocked test structurally cannot catch an argument mismatch; this can.

Run: `DB_URL="$DB_URL" bash tests/adapters/04_endpoint_arg_order.sh`
Expected: PASS, reporting **9** call sites. Write that number down — Step 5 checks it became 11.

- [ ] **Step 2: Add the two handlers**

In `packages/better-auth/src/plugin/endpoints.ts`, insert after the `listInvitations` handler (which ends at line 87) and before `listOrgMembers`:

```ts
    async cancelInvitation(userId: string, invitationId: string) {
      // public.cancel_invitation returns void, but callPublicFn always runs
      // SELECT * FROM fn(...), which for a void function yields one row with one
      // meaningless column. Passing that through would put
      // [{"cancel_invitation": ""}] in this endpoint's public contract, so
      // normalize — same as handleSetActiveOrg does.
      await withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.cancel_invitation', [invitationId])
      );
      return { success: true };
    },

    // NOTE: unlike list_invitations, this response carries the invitation TOKEN.
    // resend_invitation mints a fresh one, resets expires_at, and flips an
    // expired invitation back to pending, so the caller can re-send the email.
    // list_invitations deliberately does not re-expose tokens; this must.
    // Treat the response as a secret — do not log it.
    async resendInvitation(userId: string, invitationId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.resend_invitation', [invitationId])
      );
    },
```

The parameter name `invitationId` is load-bearing: `tests/adapters/04_endpoint_arg_order.sh` maps it to `p_invitation_id p_id`. Renaming it fails the guard.

- [ ] **Step 3: Register the two endpoints**

In `packages/better-auth/src/plugin/index.ts`, insert after `smtaListInvitations` (which ends at line 109) and before `smtaListOrgMembers`:

```ts
      smtaCancelInvitation: createAuthEndpoint(
        '/smta/invitation/:id/cancel',
        { method: 'POST', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.cancelInvitation(session.user.id, ctx.params.id);
          return ctx.json(result);
        }
      ),

      // The response body contains a fresh invitation token. Callers should send
      // it in an email and not persist or log it.
      smtaResendInvitation: createAuthEndpoint(
        '/smta/invitation/:id/resend',
        { method: 'POST', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.resendInvitation(session.user.id, ctx.params.id);
          return ctx.json(result as Record<string, unknown>[]);
        }
      ),
```

`sessionMiddleware` matches `smtaCreateInvitation`; the SQL functions do their own authorisation on top (`cancel_invitation` requires inviter or org membership and refuses anything not `pending`; `resend_invitation` requires org membership). No new error paths — failures propagate as thrown exceptions through `withSMTA`, exactly as for the four existing invitation endpoints.

There is no route collision with the existing `GET /smta/invitation/:token`: different method, different segment count.

- [ ] **Step 4: Type-check and build**

Run: `pnpm --filter @smta/better-auth lint && pnpm --filter @smta/better-auth build`
Expected: exit 0 for both. `dist/` is committed in this repo, so the build output is part of the deliverable.

- [ ] **Step 5: Run the arg-order guard to verify it picked up the new call sites**

Run: `DB_URL="$DB_URL" bash tests/adapters/04_endpoint_arg_order.sh`
Expected: PASS, now reporting **11** call sites (up from the 9 recorded in Step 1). If it still says 9, the new handlers are not being parsed — the guard matches the exact form `callPublicFn(client, 'public.<fn>', [<args>])` on a single line. Fix the formatting rather than the guard.

- [ ] **Step 6: Confirm the underlying SQL is already covered**

No new pgTap file is needed. Confirm the existing coverage actually runs and passes:

Run: `pg_prove -v "$DB_URL" tests/invitations/03_manage_invitations.sql`
Expected: PASS, 16/16 — cancel succeeds on pending, status becomes `cancelled`, re-cancelling raises, resend rotates the token, resend resets expiry and revives an expired invitation, and non-members are rejected for both.

- [ ] **Step 7: Commit**

```bash
git add packages/better-auth/src/plugin/endpoints.ts \
        packages/better-auth/src/plugin/index.ts \
        packages/better-auth/dist \
        packages/better-auth/tsconfig.tsbuildinfo
git commit -m "feat(better-auth): expose invitation cancel and resend endpoints

public.cancel_invitation and public.resend_invitation have always existed and
are well built — both authorise, both audit, and resend mints a fresh token,
resets expires_at to now() + 7 days, and flips an expired invitation back to
pending. Neither was reachable from the adapter, so an application could create
and list invitations but never cancel or resend one. An invitation to a typo'd
address was permanent until it expired.

POST /smta/invitation/:id/cancel  -> { success: true }
POST /smta/invitation/:id/resend  -> [{ id, token, email, expires_at }]

cancelInvitation does not pass its rows through. cancel_invitation returns void
and callPublicFn always runs SELECT * FROM fn(...), which for a void function
yields one row with one meaningless column; returning it verbatim would put
[{\"cancel_invitation\": \"\"}] in the public HTTP contract. Normalized to
{ success: true }, following handleSetActiveOrg.

The resend response carries a token, unlike every other read endpoint —
list_invitations deliberately does not re-expose tokens. Commented at both the
handler and the endpoint so nobody logs it.

No new test file. tests/invitations/03_manage_invitations.sql already covers
both functions in 16 assertions, and tests/adapters/04_endpoint_arg_order.sh
validates every callPublicFn site positionally against live pg_proc — its site
count goes 9 -> 11 automatically. That guard is the real-database check a mocked
test structurally cannot provide."
```

---

### Task 7: Documentation

Five files. The RPC reference signature blocks are copied by consumers, so a stale one is worse than none.

**Files:**
- Modify: `apps/docs/src/content/docs/rpc-reference/invitations.mdx` (2 blocks)
- Modify: `apps/docs/src/content/docs/rpc-reference/organizations.mdx` (2 blocks)
- Modify: `apps/docs/src/content/docs/rpc-reference/units.mdx` (2 blocks)
- Modify: `apps/docs/src/content/docs/rpc-reference/user-profile.mdx` (2 blocks)
- Modify: `apps/docs/src/content/docs/adapters/better-auth.mdx` (endpoint table)

**Interfaces:**
- Consumes: the final signatures from Tasks 1–3 and the routes from Task 6.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Update the invitation reference**

In `apps/docs/src/content/docs/rpc-reference/invitations.mdx`, in the `get_invitation_details(p_token)` signature block, add `role_label` after `role_name`:

```sql
public.get_invitation_details(p_token TEXT)
RETURNS TABLE (
  id               UUID,
  email            TEXT,
  organization_name TEXT,
  unit_name        TEXT,
  role_name        TEXT,
  role_label       TEXT,
  invited_by_name  TEXT,
  expires_at       TIMESTAMPTZ,
  status           TEXT
)
```

And in the `list_invitations(p_organization_id, p_status?)` signature block:

```sql
public.list_invitations(
  p_organization_id UUID,
  p_status          TEXT DEFAULT NULL
)
RETURNS TABLE (
  id               UUID,
  email            TEXT,
  organization_id  UUID,
  unit_id          UUID,
  role_name        TEXT,
  role_label       TEXT,
  invited_by_email TEXT,
  status           TEXT,
  expires_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ
)
```

Then add this note immediately after the `list_invitations` signature block, before the existing `**`p_status` values**` line:

```markdown
**`role_name` vs `role_label`**: `role_name` is the stable identifier (`core.roles.name`) — key your logic on it. `role_label` is the human-readable display name (`core.roles.description`) — render that. **Do not derive one from the other**: `super_admin`'s label is `Owner`, so de-slugifying the identifier yields "Super Admin", a role that does not exist. `role_label` is nullable, because a deployment may seed a role without a description.
```

- [ ] **Step 2: Update the organization reference**

In `apps/docs/src/content/docs/rpc-reference/organizations.mdx`, the `list_my_organizations()` block:

```sql
public.list_my_organizations()
RETURNS TABLE (
  id          UUID,
  name        TEXT,
  description TEXT,
  role        TEXT,
  role_label  TEXT
)
```

Add immediately after that block:

```markdown
`description` is the **organization's** description; `role_label` is the **role's** display name (`core.roles.description`), nullable. `role` remains the stable identifier — key logic on it, render `role_label`.
```

And the `list_organization_members(p_id)` block:

```sql
public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id        UUID,
  email          TEXT,
  first_name     TEXT,
  last_name      TEXT,
  role           TEXT,
  role_label     TEXT,
  is_super_admin BOOLEAN
)
```

Add immediately after that block:

```markdown
`role_label` is the role's display name, nullable. Render it rather than `role` — deriving a label from the identifier gets the owner wrong, since `super_admin`'s label is `Owner`, not "Super Admin".
```

- [ ] **Step 3: Update the unit reference**

In `apps/docs/src/content/docs/rpc-reference/units.mdx`, the `list_my_units()` block:

```sql
public.list_my_units()
RETURNS TABLE (
  id              UUID,
  organization_id UUID,
  name            TEXT,
  role            TEXT,
  role_label      TEXT
)
```

And the `list_unit_members(p_unit_id)` block:

```sql
public.list_unit_members(p_unit_id UUID)
RETURNS TABLE (
  user_id    UUID,
  email      TEXT,
  first_name TEXT,
  last_name  TEXT,
  role       TEXT,
  role_label TEXT
)
```

Leave the `list_units(p_org_id)` block alone — it projects no role.

- [ ] **Step 4: Update the user profile reference**

In `apps/docs/src/content/docs/rpc-reference/user-profile.mdx`, the `get_user_organizations()` block:

```sql
public.get_user_organizations()
RETURNS TABLE (
  id          UUID,
  name        TEXT,
  description TEXT,
  role        TEXT,
  role_label  TEXT
)
```

And the `get_user_units(p_org_id)` block:

```sql
public.get_user_units(p_org_id UUID)
RETURNS TABLE (
  id              UUID,
  organization_id UUID,
  name            TEXT,
  role            TEXT,
  role_label      TEXT
)
```

- [ ] **Step 5: Update the better-auth adapter reference**

In `apps/docs/src/content/docs/adapters/better-auth.mdx`, add two rows to the endpoint table immediately after the `smtaListInvitations` row:

```markdown
| `smtaListInvitations` | GET | List invitations for an organization; optional `?status=` filter (all statuses if omitted) |
| `smtaCancelInvitation` | POST | Cancel a pending invitation — `POST /smta/invitation/:id/cancel`, returns `{ success: true }` |
| `smtaResendInvitation` | POST | Resend an invitation with a fresh token and reset expiry — `POST /smta/invitation/:id/resend`. **The response contains an invitation token; treat it as a secret.** |
| `smtaListOrgMembers` | GET | List members of an organization |
```

- [ ] **Step 6: Build the docs site to verify nothing broke**

Run: `pnpm build:docs`
Expected: exit 0. If the docs build is not runnable in this environment, say so plainly rather than marking this step complete.

- [ ] **Step 7: Commit**

```bash
git add apps/docs/src/content/docs/rpc-reference/invitations.mdx \
        apps/docs/src/content/docs/rpc-reference/organizations.mdx \
        apps/docs/src/content/docs/rpc-reference/units.mdx \
        apps/docs/src/content/docs/rpc-reference/user-profile.mdx \
        apps/docs/src/content/docs/adapters/better-auth.mdx
git commit -m "docs: document role_label and the two new invitation endpoints

Signature blocks in the RPC reference get copied by consumers, so a stale one
is worse than none. All eight role-projecting functions now show role_label.

Each addition carries the rule that motivated the change: role_name/role is the
stable identifier to key logic on, role_label is what to render, and neither is
derivable from the other. super_admin's label is Owner, so de-slugifying the
identifier yields 'Super Admin' — a role that does not exist in the product,
and the highest-privilege one in the system.

The adapter table flags that smtaResendInvitation's response carries a token,
unlike every other read endpoint."
```

---

### Task 8: Changeset and full-suite verification

**Files:**
- Create: `.changeset/role-labels-and-invitation-management.md`

**Interfaces:**
- Consumes: everything from Tasks 1–7.
- Produces: the release note.

- [ ] **Step 1: Write the changeset**

Create `.changeset/role-labels-and-invitation-management.md`:

```markdown
---
"@smta/core": minor
"@smta/schemas": minor
"@smta/better-auth": minor
---

Return the role's display label from every function that projects a role to a user-facing surface, and expose invitation cancel/resend through the better-auth adapter.

**`role_label` on eight functions.** `core.roles` carries both a stable identifier (`name`) and a display label (`description`), but every read function returned only the identifier, so consumers rendered `operator` and `general_manager` to end users — including on the invitation landing page, the first thing an invited user ever sees.

Deriving the label from the identifier is wrong and quietly so: `super_admin`'s label is `Owner`, so de-slugifying yields "Super Admin", a role that does not exist in the product and the highest-privilege one in the system. `public.list_organization_members` is the function that renders an organization's owner, which makes it the most affected of the eight.

`role_label` is now returned by `list_invitations`, `get_invitation_details`, `list_organization_members`, `list_my_organizations`, `get_user_organizations`, `list_unit_members`, `list_my_units`, and `get_user_units` — and by the `core.*` functions behind the first two.

The label is emitted raw, so `role_label` is **nullable**: `core.roles.description` has no `NOT NULL` constraint and roles are seeded per deployment, so `NULL` genuinely means "this deployment gave the role no label". It is deliberately not coalesced to the identifier, which would render `super_admin` to an end user in exactly the case nobody tests. Render `role_label ?? role_name`.

Purely additive — the existing `role` / `role_name` columns are unchanged, and the `role` vs `role_name` naming inconsistency across these functions is deliberately left alone, since renaming would break every consumer selecting by name.

`@smta/schemas` types the new key as required and nullable (`z.string().nullable()`). All `@smta/*` packages publish at the same version, so a database missing the column is a deploy error and should raise at the first call rather than silently render a blank label.

**Invitation cancel and resend.** `public.cancel_invitation` and `public.resend_invitation` have always existed but were unreachable from the adapter, so an application could create and list invitations but never cancel or resend one — an invitation to a typo'd address was permanent until it expired.

- `POST /smta/invitation/:id/cancel` → `{ success: true }`
- `POST /smta/invitation/:id/resend` → `[{ id, token, email, expires_at }]`

Both are `sessionMiddleware`-guarded, with the SQL functions doing their own authorization on top. **The resend response carries an invitation token** — `resend_invitation` mints a fresh one so the caller can re-send the email. Unlike `list_invitations`, which deliberately never re-exposes tokens, this response is a secret: do not log or persist it.

**Applying this release:** the SQL must be re-applied. Adding a column to a `RETURNS TABLE` requires dropping and recreating the function, which the shipped SQL does inline. Upgrading the npm packages without re-running the SQL will raise a `ZodError` naming `role_label`.
```

- [ ] **Step 2: Run the full suite**

Run: `./scripts/run_tests.sh`
Expected:
- Adapter guards: all pass, `04_endpoint_arg_order.sh` reporting 11 call sites.
- pgTap: **522** assertions passing (508 baseline + 14 from `06_role_labels.sql`), 0 failures.

Read the actual output. If the count differs from 522, reconcile it before continuing — a lower number means a file did not run.

- [ ] **Step 3: Build every changed package**

Run: `pnpm --filter @smta/schemas build && pnpm --filter @smta/better-auth build && pnpm --filter @smta/better-auth lint`
Expected: exit 0 for all three. Confirm `git status` shows no unexpected uncommitted `dist/` changes — if it does, they belong in the Task 5 or Task 6 commit and should be committed now with a `chore: rebuild dist` message.

- [ ] **Step 4: Confirm the branch state**

Run: `git log --oneline main..HEAD && git status --short`
Expected: nine commits — the spec commit (`51367f7`) plus one per task — and a clean working tree apart from the untracked `docs/superpowers/smta-invitation-gaps_old.md`.

**Do not merge. Do not push.** The user has other work in flight.

- [ ] **Step 5: Commit**

```bash
git add .changeset/role-labels-and-invitation-management.md
git commit -m "chore: add changeset for role labels and invitation management

Minor across the fixed group: new columns and new endpoints are additive
features, not fixes. Per the two-stage Changesets setup, merging publishes
nothing — this only queues the bump.

The note calls out that the SQL must be re-applied, since upgrading the npm
packages alone produces a ZodError naming role_label."
```

- [ ] **Step 6: Report results honestly**

State the actual pgTap count, the actual guard call-site count, and the actual build results. If any step could not run — no database reachable, docs build unavailable — say which, and do not describe the work as verified.

---

## Verification summary

| Claim | How it is verified |
|---|---|
| Eight functions return `role_label` | `tests/functions/06_role_labels.sql`, 12 assertions |
| The label is not coalesced to the identifier | Task 4 NULL-passthrough assertion |
| Existing role identifiers are unchanged | Task 1, 2, 4 identifier assertions |
| `get_user_organizations` delegate stayed in lockstep | Task 2 explicit delegate assertion (fails at call time otherwise) |
| No existing test regressed | Full suite, 522 passing |
| The two new endpoints bind their argument correctly | `tests/adapters/04_endpoint_arg_order.sh`, 9 → 11 call sites, positional check against live `pg_proc` |
| Cancel/resend SQL semantics | `tests/invitations/03_manage_invitations.sql`, 16 assertions (pre-existing) |
| Schemas compile | `pnpm --filter @smta/schemas build` |
| Adapter compiles | `pnpm --filter @smta/better-auth lint && build` |
