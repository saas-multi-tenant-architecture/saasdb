# Better-Auth Documentation Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `@smta/better-auth` to all documentation surfaces — Starlight site and in-repo markdown files — and remove the Supabase-specific pg-graphql block from `installation.mdx`.

**Architecture:** Purely content changes. New MDX pages mirror existing adapter/quickstart pages in structure. Existing pages receive targeted insertions. Verification after each task is a Starlight build (`pnpm --filter @smta/docs build`) to catch broken frontmatter, missing slugs, or import errors.

**Tech Stack:** Astro Starlight (MDX), pnpm monorepo, Markdown.

---

## File Map

**Create:**
- `apps/docs/src/content/docs/getting-started/quickstart-better-auth.mdx`
- `apps/docs/src/content/docs/adapters/better-auth.mdx`

**Modify (Starlight site):**
- `apps/docs/astro.config.mjs` — sidebar entries
- `apps/docs/src/content/docs/getting-started/installation.mdx` — remove pg-graphql block, add better-auth option
- `apps/docs/src/content/docs/getting-started/what-is-smta.mdx` — layer table + "Does Not Provide"
- `apps/docs/src/content/docs/architecture/adapter-pattern.mdx` — better-auth section + Package Boundaries table

**Modify (in-repo markdown):**
- `README.md` — layer diagram, Extensible Connections, Goals, Project Structure, Package Boundaries, Deployment, test count
- `TESTING.md` — add `tests/adapters/` category
- `packages/cli/README.md` — add better-auth to adapter table and examples
- `packages/better-auth/README.md` — update adapter test section
- `packages/core/README.md` — package family table
- `packages/supabase/README.md` — package family table
- `packages/payload/README.md` — package family table

---

### Task 1: Add better-auth to Starlight sidebar

**Files:**
- Modify: `apps/docs/astro.config.mjs`

- [ ] **Step 1: Add sidebar entries**

In `apps/docs/astro.config.mjs`, update the `sidebar` array:

```javascript
// Getting Started — add after quickstart-payload entry:
{ label: 'Quick Start: better-auth', slug: 'getting-started/quickstart-better-auth' },

// Adapters — add after payload entry:
{ label: 'Better Auth', slug: 'adapters/better-auth' },
```

The full updated sections:

```javascript
{
  label: 'Getting Started',
  items: [
    { label: 'What is SMTA?', slug: 'getting-started/what-is-smta' },
    { label: 'Installation', slug: 'getting-started/installation' },
    { label: 'Quick Start: Supabase', slug: 'getting-started/quickstart-supabase' },
    { label: 'Quick Start: Payload', slug: 'getting-started/quickstart-payload' },
    { label: 'Quick Start: better-auth', slug: 'getting-started/quickstart-better-auth' },
  ],
},
// ...
{
  label: 'Adapters',
  items: [
    { label: 'Supabase', slug: 'adapters/supabase' },
    { label: 'Payload CMS', slug: 'adapters/payload' },
    { label: 'Better Auth', slug: 'adapters/better-auth' },
  ],
},
```

- [ ] **Step 2: Commit**

```bash
git add apps/docs/astro.config.mjs
git commit -m "docs(site): add better-auth entries to Starlight sidebar"
```

---

### Task 2: Create `quickstart-better-auth.mdx`

**Files:**
- Create: `apps/docs/src/content/docs/getting-started/quickstart-better-auth.mdx`

- [ ] **Step 1: Create the file**

```mdx
---
title: Quick Start — better-auth
description: Get SMTA running with a better-auth project.
---

import { Aside } from '@astrojs/starlight/components';

## 1. Prerequisites

- A [better-auth](https://www.better-auth.com/) v1.x project connected to a PostgreSQL database
- `generateId` configured to produce UUIDs — SMTA's primary keys are UUID and the new-user trigger casts better-auth's `TEXT` id to `UUID`:

```typescript
export const auth = betterAuth({
  generateId: () => crypto.randomUUID(),
  // ...
})
```

<Aside type="caution">
Run better-auth's database migration **before** applying the SMTA SQL. The new-user trigger targets better-auth's `user` table, which must exist before the trigger can attach to it.

```bash
npx better-auth migrate
```
</Aside>

## 2. Generate and Apply the SQL

```bash
npx @smta/cli --adapter better-auth
# → SMTA-better-auth-<timestamp>.sql  (60 SQL files combined)
```

Apply the generated script to your database:

```bash
psql "$DATABASE_URL" -f SMTA-better-auth-<timestamp>.sql
```

## 3. What the Adapter Provides

The better-auth deployment includes two adapter-specific files on top of `@smta/core`:

| File | Purpose |
|---|---|
| `auth_better_auth_impl.sql` | Implements `core.get_current_user_id()` using the `app.current_user_id` PostgreSQL session variable |
| `new_user_trigger.sql` | Auto-creates `core.users_meta` rows when a user signs up via better-auth |

## 4. Register the Plugin

Install the TypeScript package:

```bash
npm install @smta/better-auth pg
```

Register `smtaPlugin` in your better-auth config:

```typescript
import { betterAuth } from 'better-auth'
import { smtaPlugin } from '@smta/better-auth'
import { pool } from '@/lib/db' // your pg Pool instance

export const auth = betterAuth({
  generateId: () => crypto.randomUUID(),
  plugins: [smtaPlugin({ pool })],
})
```

Use `withSMTA()` in Next.js Route Handlers or Server Actions to set the user context before querying SMTA functions:

```typescript
import { auth } from '@/lib/auth'
import { withSMTA } from '@smta/better-auth'
import { pool } from '@/lib/db'

export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers })

  return withSMTA(pool, session?.user?.id, async (client) => {
    const { rows } = await client.query(
      'SELECT * FROM public.list_my_organizations()'
    )
    return Response.json(rows)
  })
}
```

`withSMTA()` sets `app.current_user_id` using `SET LOCAL`, scoping it to the transaction. SMTA's RLS policies read this value on every query.

## 5. Verify

In `psql` or your SQL client:

```sql
-- Set the session variable to a known user ID
SET app.current_user_id = 'your-user-uuid-here';

-- Should return an empty array (no orgs yet for this user)
SELECT public.list_my_organizations();
```

If the function returns without error, SMTA is deployed and the auth wiring is in place.

## 6. Add Your App Schema

Create your `app` schema tables referencing `core.organizations` or `core.units`, enable RLS, and write policies that call `core.get_current_user_id()`.

```sql
CREATE SCHEMA IF NOT EXISTS app;

-- Org-scoped table: any member of the org can access
CREATE TABLE app.projects (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID NOT NULL REFERENCES core.organizations(id),
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE app.projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members" ON app.projects
  FOR ALL USING (core.is_org_member(org_id));
```
```

- [ ] **Step 2: Verify Starlight build**

```bash
pnpm --filter @smta/docs build 2>&1 | tail -20
```

Expected: build completes with no errors. The new page should appear in the output.

- [ ] **Step 3: Commit**

```bash
git add apps/docs/src/content/docs/getting-started/quickstart-better-auth.mdx
git commit -m "docs(site): add better-auth quick start page"
```

---

### Task 3: Create `adapters/better-auth.mdx`

**Files:**
- Create: `apps/docs/src/content/docs/adapters/better-auth.mdx`

- [ ] **Step 1: Create the file**

```mdx
---
title: Better Auth Adapter
description: What the @smta/better-auth adapter provides and how to configure it.
---

The `@smta/better-auth` adapter wires SMTA's auth interface to better-auth's session context via a PostgreSQL session variable, auto-syncs new users to SMTA's user table, and adds SMTA tenant management as `auth.api.smta*` endpoints.

## What It Contains

| File | Purpose |
|---|---|
| `auth_better_auth_impl.sql` | Implements `core.get_current_user_id()` via the `app.current_user_id` session variable |
| `new_user_trigger.sql` | Trigger on better-auth's `user` table — creates `core.users_meta` on signup |

## Auth Implementation

```sql
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

Your application sets this session variable at the start of each request using `withSMTA()` from `@smta/better-auth`:

```typescript
import { withSMTA } from '@smta/better-auth'

return withSMTA(pool, session?.user?.id, async (client) => {
  // All queries inside this callback run with app.current_user_id set.
  // SMTA's RLS policies enforce tenant isolation automatically.
  const { rows } = await client.query('SELECT * FROM public.list_my_organizations()')
  return Response.json(rows)
})
```

`withSMTA()` uses `SET LOCAL` so the session variable is scoped to the transaction — it is automatically cleared when the transaction ends.

## User Sync

The `new_user_trigger.sql` file creates a trigger on better-auth's `user` table. When a new user signs up, the trigger inserts a corresponding row into `core.users_meta`:

```sql
CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = core AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id::UUID, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
```

This requires better-auth to generate UUID IDs. Configure `generateId` in your better-auth setup:

```typescript
export const auth = betterAuth({
  generateId: () => crypto.randomUUID(),
  plugins: [smtaPlugin({ pool })],
})
```

## Plugin Endpoints

`smtaPlugin()` extends the better-auth client with SMTA tenant management endpoints. All endpoints enforce RLS — users can only affect organizations they are members of, enforced at the database layer.

| Endpoint | Method | Description |
|---|---|---|
| `smtaCreateOrganization` | POST | Create a new organization |
| `smtaListOrganizations` | GET | List organizations the user is a member of |
| `smtaGetOrganization` | GET | Get a single organization by ID |
| `smtaCreateInvitation` | POST | Invite a user to an organization |
| `smtaAcceptInvitation` | POST | Accept an invitation by token |
| `smtaGetInvitationDetails` | GET | Get invitation details (public — no auth required) |
| `smtaListInvitations` | GET | List pending invitations for an organization |
| `smtaListOrgMembers` | GET | List members of an organization |
| `smtaGetUserPermissions` | GET | Get the current user's permissions within an org |
| `smtaSetActiveOrg` | POST | Set the active organization in the session |

`smtaPlugin()` also adds `activeOrgId` to the better-auth session schema — a nullable string that tracks which organization is currently in context for multi-org users. It is set by the client via `smtaSetActiveOrg` and cleared by passing `null`.

## Secrets

The better-auth adapter does not implement `core.store_secret_impl()` or `core.delete_secret_impl()`. These remain as exception-raising stubs. Calling them without an implementation will raise a database exception. If you need per-tenant secret storage, implement the stubs using your preferred secret manager (AWS Secrets Manager, HashiCorp Vault, etc.).

## Deployment

```bash
npx @smta/cli --adapter better-auth
# → SMTA-better-auth-<timestamp>.sql  (60 SQL files combined)
```

Apply to your database:

```bash
psql "$DATABASE_URL" -f SMTA-better-auth-<timestamp>.sql
```

See the [Quick Start: better-auth](/getting-started/quickstart-better-auth/) for the full setup walkthrough.
```

- [ ] **Step 2: Verify Starlight build**

```bash
pnpm --filter @smta/docs build 2>&1 | tail -20
```

Expected: build completes with no errors.

- [ ] **Step 3: Commit**

```bash
git add apps/docs/src/content/docs/adapters/better-auth.mdx
git commit -m "docs(site): add better-auth adapter reference page"
```

---

### Task 4: Update `installation.mdx`

**Files:**
- Modify: `apps/docs/src/content/docs/getting-started/installation.mdx`

- [ ] **Step 1: Make four changes to the file**

**Change 1** — Prerequisites: replace the Supabase/Payload-specific line:

```
# Remove:
- A Supabase project **or** a Payload CMS project with a PostgreSQL connection

# Replace with:
- A PostgreSQL-connected platform: Supabase, Payload CMS, or better-auth
```

**Change 2** — CLI examples: add the better-auth option:

```bash
# For Supabase
npx @smta/cli --adapter supabase # [--enable-graphql] Optional flag to keep GraphQL enabled
# → SMTA-supabase-<timestamp>.sql  (59 SQL files combined)

# For Payload CMS
npx @smta/cli --adapter payload
# → SMTA-payload-<timestamp>.sql  (57 SQL files combined)

# For better-auth
npx @smta/cli --adapter better-auth
# → SMTA-better-auth-<timestamp>.sql  (60 SQL files combined)
```

**Change 3** — Remove the entire pg-graphql block (the "## pg-graphql Extension Disabled" section and all its content). It already lives in `quickstart-supabase.mdx` and `adapters/supabase.mdx`.

**Change 4** — Next Steps: add the better-auth quickstart link:

```markdown
- [Quick Start: Supabase](/getting-started/quickstart-supabase/)
- [Quick Start: Payload CMS](/getting-started/quickstart-payload/)
- [Quick Start: better-auth](/getting-started/quickstart-better-auth/)
```

- [ ] **Step 2: Verify Starlight build**

```bash
pnpm --filter @smta/docs build 2>&1 | tail -20
```

Expected: build completes with no errors.

- [ ] **Step 3: Commit**

```bash
git add apps/docs/src/content/docs/getting-started/installation.mdx
git commit -m "docs(site): add better-auth to installation page, remove misplaced pg-graphql block"
```

---

### Task 5: Update `what-is-smta.mdx` and `adapter-pattern.mdx`

**Files:**
- Modify: `apps/docs/src/content/docs/getting-started/what-is-smta.mdx`
- Modify: `apps/docs/src/content/docs/architecture/adapter-pattern.mdx`

- [ ] **Step 1: Update `what-is-smta.mdx`**

**Change 1** — Three Layers table, Platform Layer row:

```
# Remove:
| **Platform Layer** | Authentication: Supabase JWT or Payload CMS session |

# Replace with:
| **Platform Layer** | Authentication adapter: Supabase JWT, Payload CMS session, or better-auth session variable |
```

**Change 2** — "What SMTA Does Not Provide" list:

```
# Remove:
- Authentication — delegated to your adapter (Supabase or Payload)

# Replace with:
- Authentication — delegated to your adapter (Supabase, Payload CMS, or better-auth)
```

- [ ] **Step 2: Update `adapter-pattern.mdx`**

**Change 1** — After the Payload adapter block, add a better-auth adapter block:

```markdown
**better-auth adapter** (`@smta/better-auth`) replaces the auth stub only (same pattern as Payload):

```sql
-- auth_better_auth_impl.sql
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

The better-auth adapter also ships a trigger (`new_user_trigger.sql`) that auto-creates `core.users_meta` rows on signup — this is unique to this adapter. The secret stubs remain as exception-raising guards, the same as Payload.
```

**Change 2** — Package Boundaries table at the bottom: add a row for `@smta/better-auth`:

```markdown
| Package | Contains |
|---|---|
| `@smta/core` | All adapter-agnostic SQL (58 files) |
| `@smta/supabase` | Auth + secrets impl + auth.users FK constraints (3 files) |
| `@smta/payload` | Auth impl only (1 file) |
| `@smta/better-auth` | Auth impl + new-user trigger (2 files) + TypeScript plugin |
```

Note: the existing table says 56 files for core — the correct count is 58. Update this while editing.

- [ ] **Step 3: Verify Starlight build**

```bash
pnpm --filter @smta/docs build 2>&1 | tail -20
```

Expected: build completes with no errors.

- [ ] **Step 4: Commit**

```bash
git add apps/docs/src/content/docs/getting-started/what-is-smta.mdx \
        apps/docs/src/content/docs/architecture/adapter-pattern.mdx
git commit -m "docs(site): add better-auth to overview and adapter pattern pages"
```

---

### Task 6: Update package family tables (core, supabase, payload READMEs)

**Files:**
- Modify: `packages/core/README.md`
- Modify: `packages/supabase/README.md`
- Modify: `packages/payload/README.md`

Each file has a "Part of the SMTA package family" table. Add the `@smta/better-auth` row to each.

- [ ] **Step 1: Update `packages/core/README.md`**

Add after the `@smta/payload` row:

```markdown
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + TypeScript plugin |
```

Full updated table:

```markdown
| Package | Purpose |
|---------|---------|
| **`@smta/core`** | This package — adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase auth and Vault adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + TypeScript plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |
```

- [ ] **Step 2: Update `packages/supabase/README.md`**

Same addition. Full updated table:

```markdown
| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| **`@smta/supabase`** | This package — Supabase adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + TypeScript plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |
```

- [ ] **Step 3: Update `packages/payload/README.md`**

Same addition. Full updated table:

```markdown
| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase adapter SQL |
| **`@smta/payload`** | This package — Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + TypeScript plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |
```

- [ ] **Step 4: Commit**

```bash
git add packages/core/README.md packages/supabase/README.md packages/payload/README.md
git commit -m "docs: add @smta/better-auth to package family tables"
```

---

### Task 7: Update `packages/cli/README.md` and `packages/better-auth/README.md`

**Files:**
- Modify: `packages/cli/README.md`
- Modify: `packages/better-auth/README.md`

- [ ] **Step 1: Update `packages/cli/README.md`**

**Change 1** — Usage section: add the better-auth example after the Payload example:

```bash
# Supabase deployment (59 SQL files)
npx @smta/cli --adapter supabase
# → SMTA-supabase-<timestamp>.sql

# Payload CMS deployment (57 SQL files)
npx @smta/cli --adapter payload
# → SMTA-payload-<timestamp>.sql

# better-auth deployment (60 SQL files)
npx @smta/cli --adapter better-auth
# → SMTA-better-auth-<timestamp>.sql
```

**Change 2** — Options table: add `better-auth` as a valid adapter value:

```markdown
| Flag | Default | Description |
|------|---------|-------------|
| `--adapter` | `supabase` | Adapter to use: `supabase`, `payload`, or `better-auth` |
```

**Change 3** — Package family table: add `@smta/better-auth` row:

```markdown
| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + TypeScript plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| **`@smta/cli`** | This package — Deployment CLI |
```

- [ ] **Step 2: Update `packages/better-auth/README.md`**

Replace the "Running the adapter tests" section with:

```markdown
## Running the adapter tests

The adapter tests are included in the main SMTA test suite and run automatically via `pnpm test` when fixture data is loaded. No separate setup is needed.

To run the adapter tests in isolation against a better-auth-deployed database (with fixtures loaded manually):

```bash
# Load fixtures first
psql $DATABASE_URL -f tests/fixtures/00_test_helpers.sql
psql $DATABASE_URL -f tests/fixtures/01_roles.sql
psql $DATABASE_URL -f tests/fixtures/02_test_users.sql
psql $DATABASE_URL -f tests/fixtures/03_bella_italia.sql

# Run adapter tests
pg_prove -v "$DATABASE_URL" tests/adapters/01_better_auth_adapter.sql
```
```

- [ ] **Step 3: Commit**

```bash
git add packages/cli/README.md packages/better-auth/README.md
git commit -m "docs: update CLI and better-auth READMEs for better-auth adapter"
```

---

### Task 8: Update root `README.md` and `TESTING.md`

**Files:**
- Modify: `README.md`
- Modify: `TESTING.md`

- [ ] **Step 1: Update `README.md`**

**Change 1** — Layer diagram table: add better-auth to the Platform Layer row:

```markdown
| Platform Layer | Authentication adapter: Supabase, PayloadCMS, or better-auth |
```

**Change 2** — "Extensible Connections" section: add a better-auth bullet after the PayloadCMS bullet:

```markdown
- **better-auth** — The `@smta/better-auth` adapter wires SMTA's auth interface to better-auth's session context via a PostgreSQL session variable, adds SMTA tenant management as `auth.api.smta*` endpoints, and auto-syncs new users to `core.users_meta` via a trigger.
```

**Change 3** — Goals section: update the adapter-agnostic line:

```
# Remove:
- Adapter-agnostic core — same full feature set under Supabase or PayloadCMS

# Replace with:
- Adapter-agnostic core — same full feature set under Supabase, PayloadCMS, or better-auth
```

**Change 4** — Project Structure code block: add `@smta/better-auth`:

```
packages/
├── core/          @smta/core         — adapter-agnostic SMTA schema (SQL)
├── supabase/      @smta/supabase     — Supabase auth/secrets adapter (SQL)
├── payload/       @smta/payload      — PayloadCMS auth adapter (SQL + TypeScript)
├── better-auth/   @smta/better-auth  — better-auth adapter (SQL + TypeScript)
├── billing/       @smta/billing      — BillingProvider interface + Stripe + Lemon Squeezy (TypeScript)
└── schemas/       @smta/schemas      — Zod v4 schemas for public.* RPC contracts (TypeScript)
```

**Change 5** — Package boundaries table: add `@smta/better-auth` row and fix core file count (56 → 58):

```markdown
| Package | Contains |
|---|---|
| `@smta/core` | Core + platform schema, billing tables, RLS, public functions, triggers (58 SQL files) |
| `@smta/supabase` | JWT auth impl, Vault secrets impl, `auth.users` FK constraints (3 SQL files) |
| `@smta/payload` | Session-variable auth impl (1 SQL file) + TypeScript middleware |
| `@smta/better-auth` | Session-variable auth impl + new-user trigger (2 SQL files) + TypeScript plugin |
| `@smta/billing` | `BillingProvider` interface, `StripeProvider`, `LemonSqueezyProvider` |
| `@smta/schemas` | Zod v4 schemas for all `public.*` RPC function inputs/outputs |
```

**Change 6** — Deployment section: add the better-auth build command:

```bash
# Supabase deployment (59 files)
npm run build:supabase   # → output/SMTA-supabase-<timestamp>.sql

# Payload deployment (57 files)
npm run build:payload    # → output/SMTA-payload-<timestamp>.sql

# better-auth deployment (60 files)
npm run build:better-auth   # → output/SMTA-better-auth-<timestamp>.sql
```

**Change 7** — Testing section: update test count:

```
# Remove:
SMTA uses [pgTap](https://pgtap.org/) for database-level testing (35 test files, 449 tests).

# Replace with:
SMTA uses [pgTap](https://pgtap.org/) for database-level testing (41 test files, 506 tests).
```

- [ ] **Step 2: Update `TESTING.md`**

In the "Test Structure" section, the numbered list currently ends at 8 categories. Add `tests/adapters/` as category 8 and renumber "edge_cases" as 7 if needed. The current list is:

```
1. tests/fixtures/
2. tests/schema/
3. tests/membership/
4. tests/triggers/
5. tests/platform/
6. tests/functions/
7. tests/rls/
8. tests/edge_cases/
```

Add after item 8:

```markdown
9. **`tests/adapters/`** - Adapter-specific integration tests (loaded after fixtures, rolled back after each file)
   - `01_better_auth_adapter.sql` - Tests `core.get_current_user_id()`, the new-user trigger, and the RLS chain end-to-end
```

- [ ] **Step 3: Commit**

```bash
git add README.md TESTING.md
git commit -m "docs: update root README and TESTING.md for better-auth adapter"
```

---

## Self-Review Checklist

Run after all tasks are complete:

- [ ] `pnpm --filter @smta/docs build` passes with zero errors
- [ ] Sidebar links in `astro.config.mjs` match the actual file slugs created in Tasks 2 and 3
- [ ] `packages/better-auth/README.md` adapter test section no longer references the old standalone-only workflow
- [ ] All 7 "Part of the SMTA package family" tables include `@smta/better-auth` (core, supabase, payload, cli READMEs + the 3 cross-reference tables)
- [ ] Root `README.md` test count reads 41 files, 506 tests
- [ ] `adapter-pattern.mdx` Package Boundaries table shows 58 files for `@smta/core`
