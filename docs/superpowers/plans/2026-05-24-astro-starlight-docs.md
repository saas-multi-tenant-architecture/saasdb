# SMTA Documentation Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a public-facing Astro Starlight documentation site at `apps/docs/` inside the existing pnpm monorepo, auto-deployed to Cloudflare Pages on push to `master`.

**Architecture:** `apps/docs/` is an `@smta/docs` pnpm workspace member with no runtime dependencies on other packages. Astro Starlight produces a static site (`output: 'static'`). Cloudflare Pages connects to the GitHub repo and deploys automatically on every push to `master`.

**Tech Stack:** Astro 6.3.7, @astrojs/starlight 0.39.2, pnpm workspace, Turborepo

---

## File Map

**Created:**
- `apps/docs/package.json` — workspace member config + Astro/Starlight deps
- `apps/docs/astro.config.mjs` — Starlight config with all 7 nav sections
- `apps/docs/tsconfig.json` — strict Astro TypeScript config
- `apps/docs/src/env.d.ts` — Astro type reference
- `apps/docs/src/content/docs/index.mdx` — landing/splash page
- `apps/docs/src/content/docs/getting-started/what-is-smta.md`
- `apps/docs/src/content/docs/getting-started/installation.md`
- `apps/docs/src/content/docs/getting-started/quickstart-supabase.md`
- `apps/docs/src/content/docs/getting-started/quickstart-payload.md`
- `apps/docs/src/content/docs/architecture/overview.md`
- `apps/docs/src/content/docs/architecture/schema-boundaries.md`
- `apps/docs/src/content/docs/architecture/tenant-isolation.md`
- `apps/docs/src/content/docs/architecture/adapter-pattern.md`
- `apps/docs/src/content/docs/adapters/supabase.md`
- `apps/docs/src/content/docs/adapters/payload.md`
- `apps/docs/src/content/docs/rpc-reference/organizations.md`
- `apps/docs/src/content/docs/rpc-reference/units.md`
- `apps/docs/src/content/docs/rpc-reference/user-profile.md`
- `apps/docs/src/content/docs/rpc-reference/invitations.md`
- `apps/docs/src/content/docs/rpc-reference/files.md`
- `apps/docs/src/content/docs/rpc-reference/secrets.md`
- `apps/docs/src/content/docs/rpc-reference/audit.md`
- `apps/docs/src/content/docs/rpc-reference/products.md`
- `apps/docs/src/content/docs/billing/overview.md`
- `apps/docs/src/content/docs/billing/stripe.md`
- `apps/docs/src/content/docs/billing/lemon-squeezy.md`
- `apps/docs/src/content/docs/testing/setup.md`
- `apps/docs/src/content/docs/testing/running.md`
- `apps/docs/src/content/docs/contributing/package-structure.md`
- `apps/docs/src/content/docs/contributing/adding-sql.md`
- `apps/docs/src/content/docs/contributing/test-conventions.md`

**Modified:**
- `pnpm-workspace.yaml` — add `apps/*`
- `package.json` (root) — add `build:docs` script

---

## Task 1: Scaffold Astro Starlight Project

**Files:**
- Create: `apps/docs/package.json`
- Create: `apps/docs/astro.config.mjs`
- Create: `apps/docs/tsconfig.json`
- Create: `apps/docs/src/env.d.ts`
- Create: `apps/docs/src/content/docs/index.mdx`

- [ ] **Step 1.1: Create `apps/docs/package.json`**

```json
{
  "name": "@smta/docs",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview"
  },
  "dependencies": {
    "@astrojs/starlight": "^0.39.2",
    "astro": "^6.3.7"
  }
}
```

- [ ] **Step 1.2: Create `apps/docs/astro.config.mjs`**

```javascript
import { defineConfig } from 'astro/config'
import starlight from '@astrojs/starlight'

export default defineConfig({
  output: 'static',
  integrations: [
    starlight({
      title: 'SMTA',
      description: 'SaaS Multi-Tenant Architecture — PostgreSQL multi-tenancy for your SaaS',
      social: [
        // Update href to your GitHub repo URL before deploying
        { icon: 'github', label: 'GitHub', href: 'https://github.com/YOUR_ORG/saasdb' },
      ],
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'What is SMTA?', slug: 'getting-started/what-is-smta' },
            { label: 'Installation', slug: 'getting-started/installation' },
            { label: 'Quick Start: Supabase', slug: 'getting-started/quickstart-supabase' },
            { label: 'Quick Start: Payload', slug: 'getting-started/quickstart-payload' },
          ],
        },
        {
          label: 'Architecture',
          items: [
            { label: 'Overview', slug: 'architecture/overview' },
            { label: 'Schema Boundaries', slug: 'architecture/schema-boundaries' },
            { label: 'Tenant Isolation & RLS', slug: 'architecture/tenant-isolation' },
            { label: 'Adapter Pattern', slug: 'architecture/adapter-pattern' },
          ],
        },
        {
          label: 'Adapters',
          items: [
            { label: 'Supabase', slug: 'adapters/supabase' },
            { label: 'Payload CMS', slug: 'adapters/payload' },
          ],
        },
        {
          label: 'Public RPC Reference',
          items: [
            { label: 'Organizations', slug: 'rpc-reference/organizations' },
            { label: 'Units', slug: 'rpc-reference/units' },
            { label: 'User Profile', slug: 'rpc-reference/user-profile' },
            { label: 'Invitations', slug: 'rpc-reference/invitations' },
            { label: 'Files', slug: 'rpc-reference/files' },
            { label: 'Secrets', slug: 'rpc-reference/secrets' },
            { label: 'Audit', slug: 'rpc-reference/audit' },
            { label: 'Products', slug: 'rpc-reference/products' },
          ],
        },
        {
          label: 'Billing Integration',
          items: [
            { label: 'Overview', slug: 'billing/overview' },
            { label: 'Stripe', slug: 'billing/stripe' },
            { label: 'Lemon Squeezy', slug: 'billing/lemon-squeezy' },
          ],
        },
        {
          label: 'Testing',
          items: [
            { label: 'Setup', slug: 'testing/setup' },
            { label: 'Running the Test Suite', slug: 'testing/running' },
          ],
        },
        {
          label: 'Contributing',
          items: [
            { label: 'Package Structure', slug: 'contributing/package-structure' },
            { label: 'Adding SQL', slug: 'contributing/adding-sql' },
            { label: 'Test Conventions', slug: 'contributing/test-conventions' },
          ],
        },
      ],
    }),
  ],
})
```

- [ ] **Step 1.3: Create `apps/docs/tsconfig.json`**

```json
{
  "extends": "astro/tsconfigs/strict"
}
```

- [ ] **Step 1.4: Create `apps/docs/src/env.d.ts`**

```typescript
/// <reference path="../.astro/types.d.ts" />
```

- [ ] **Step 1.5: Create the landing page `apps/docs/src/content/docs/index.mdx`**

```mdx
---
title: SMTA — SaaS Multi-Tenant Architecture
description: A ready-made PostgreSQL multi-tenancy solution for your SaaS application.
template: splash
hero:
  tagline: Bootstrap your multi-tenant SaaS database in minutes, not months.
  actions:
    - text: Get Started
      link: /getting-started/what-is-smta/
      icon: right-arrow
    - text: View on GitHub
      link: https://github.com/YOUR_ORG/saasdb
      icon: external
      variant: minimal
---

## What is SMTA?

**SMTA** is an open-source PostgreSQL multi-tenancy framework. It provides the tenant isolation, membership management, auditing, and billing integration that every SaaS application needs — so you can focus on building your product instead of reinventing infrastructure.

## Key Features

- **Tenant isolation** via PostgreSQL Row-Level Security (RLS)
- **Org and unit hierarchy** for flexible team structures
- **Soft deletion** and no-code auditing at the database level
- **Adapter model** — the same full feature set under Supabase or Payload CMS
- **Billing integration** for Stripe and Lemon Squeezy
- **Plain SQL** — no extensions, no magic, just PostgreSQL
```

- [ ] **Step 1.6: Commit scaffold**

```bash
git add apps/docs/
git commit -m "feat: scaffold Astro Starlight docs site"
```

---

## Task 2: Wire into Monorepo and Verify Build

**Files:**
- Modify: `pnpm-workspace.yaml`
- Modify: `package.json` (root)

- [ ] **Step 2.1: Add `apps/*` to `pnpm-workspace.yaml`**

```yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

- [ ] **Step 2.2: Add `build:docs` script to root `package.json`**

The root `package.json` `scripts` section becomes:

```json
"scripts": {
  "test": "./scripts/run_tests.sh",
  "build:supabase": "node ./scripts/combine_files.js --adapter supabase",
  "build:payload": "node ./scripts/combine_files.js --adapter payload",
  "build": "npm run build:supabase && npm run build:payload",
  "build:docs": "pnpm --filter @smta/docs build"
}
```

- [ ] **Step 2.3: Install dependencies**

```bash
pnpm install
```

Expected: pnpm resolves `@smta/docs` as a new workspace member and installs Astro and Starlight into `apps/docs/node_modules/`.

- [ ] **Step 2.4: Verify the build produces output**

```bash
pnpm --filter @smta/docs build
```

Expected output ends with something like:
```
✓ Completed in Xs.
```

And `apps/docs/dist/` exists and contains `index.html`.

- [ ] **Step 2.5: Commit**

```bash
git add pnpm-workspace.yaml package.json pnpm-lock.yaml
git commit -m "feat: add @smta/docs to pnpm workspace"
```

---

## Task 3: Getting Started Section

**Files:**
- Create: `apps/docs/src/content/docs/getting-started/what-is-smta.md`
- Create: `apps/docs/src/content/docs/getting-started/installation.md`
- Create: `apps/docs/src/content/docs/getting-started/quickstart-supabase.md`
- Create: `apps/docs/src/content/docs/getting-started/quickstart-payload.md`

- [ ] **Step 3.1: Create `what-is-smta.md`**

```markdown
---
title: What is SMTA?
description: An introduction to SaaS Multi-Tenant Architecture and what it provides.
---

**SMTA** (SaaS Multi-Tenant Architecture) is a PostgreSQL framework that handles the tenant infrastructure common to every SaaS application: organizations, sub-units, memberships, roles, auditing, and billing. It sits between your platform (Supabase or Payload CMS) and your application tables.

## The Three Layers

| Layer | Your Responsibility |
|---|---|
| **Application Layer** | Your domain tables (`app` schema): projects, posts, documents, etc. Accessed via your DAL (CASL, Drizzle, Payload collections) |
| **SMTA Layer** | Tenant infrastructure: orgs, units, memberships, roles, audit, billing. Accessed via `public.*` SQL functions |
| **Platform Layer** | Authentication: Supabase JWT or Payload CMS session |

SMTA occupies the middle layer. You bring the application on top and pick the platform below.

## What SMTA Asks

SMTA's core question is: *"Are you a member of this organization or unit?"* — a yes/no gate on row visibility enforced at the database level via Row-Level Security (RLS).

Once that gate is answered, your application layer (using CASL or another RBAC tool) asks the follow-up: *"Given that you have access, what are you allowed to do?"*

## What SMTA Provides

- **Organizations** — top-level tenants with members and roles
- **Units** — sub-groups within an organization (teams, departments, projects)
- **Memberships** — links users to orgs and units with assigned roles
- **Roles** — named roles scoped per organization
- **Invitations** — invite users to join an organization by email
- **Audit logs** — automatic change tracking at the database level
- **Soft deletion** — records are flagged deleted, not physically removed
- **Billing** — subscription product and plan management, integrated with Stripe or Lemon Squeezy
- **Secrets** — per-tenant secret storage via the adapter's secret mechanism
- **Files** — file metadata tracking scoped to organizations

## What SMTA Does Not Provide

- Authentication — delegated to your adapter (Supabase or Payload)
- Application business logic — that lives in your `app` schema
- A backend API — `public.*` functions are exposed via PostgREST (Supabase) or your Payload API layer
```

- [ ] **Step 3.2: Create `installation.md`**

```markdown
---
title: Installation
description: How to deploy SMTA to your PostgreSQL database.
---

## Prerequisites

- A PostgreSQL database (version 14 or later)
- `psql` or another SQL client to apply the script
- Node.js 18+ and pnpm installed (to generate the deployment script)
- A Supabase project **or** a Payload CMS project with a PostgreSQL connection

## Generate the Deployment Script

Clone the SMTA repository and generate a combined SQL script for your chosen adapter:

```bash
# For Supabase
npm run build:supabase
# → output/SMTA-supabase-<timestamp>.sql  (59 SQL files combined)

# For Payload CMS
npm run build:payload
# → output/SMTA-payload-<timestamp>.sql  (57 SQL files combined)
```

Both scripts deploy the full SMTA feature set. The only difference is the auth implementation and, for Supabase, the restoration of `auth.users` foreign keys.

## Apply to Your Database

Apply the generated script to your PostgreSQL database:

```bash
psql -h YOUR_HOST -U YOUR_USER -d YOUR_DATABASE -f output/SMTA-supabase-<timestamp>.sql
```

For Supabase, you can paste the contents directly into the Supabase SQL Editor.

## After Deployment

SMTA creates the following schemas in your database:

- `core` — identity, access, memberships, roles, audit
- `platform` — SaaS-wide management, billing, overrides (service role only)
- `utils` — shared utility functions
- `public` — callable SQL functions (RPC interface)

Your application tables go in the `app` schema, which SMTA does not create — you define it to match your domain.

## Next Steps

Follow the Quick Start guide for your adapter:

- [Quick Start: Supabase](/getting-started/quickstart-supabase/)
- [Quick Start: Payload CMS](/getting-started/quickstart-payload/)
```

- [ ] **Step 3.3: Create `quickstart-supabase.md`**

```markdown
---
title: Quick Start — Supabase
description: Get SMTA running with a Supabase project.
---

## 1. Create a Supabase Project

If you don't have one, create a project at [supabase.com](https://supabase.com). Note your project's database connection string and service role key.

## 2. Generate and Apply the SQL

```bash
npm run build:supabase
```

Open your Supabase project → **SQL Editor** → paste the contents of `output/SMTA-supabase-<timestamp>.sql` and run it.

Alternatively, apply via `psql`:

```bash
psql "$DATABASE_URL" -f output/SMTA-supabase-<timestamp>.sql
```

## 3. What the Supabase Adapter Provides

The Supabase deployment includes three adapter-specific files on top of `@smta/core`:

| File | Purpose |
|---|---|
| `auth_supabase_impl.sql` | Implements `core.get_current_user_id()` using Supabase's JWT (`auth.uid()`) |
| `secrets_supabase_impl.sql` | Implements `core.store_secret_impl()` and `core.delete_secret_impl()` using Supabase Vault |
| `constraints.sql` | Restores foreign keys from SMTA tables to `auth.users` |

## 4. Verify

In the SQL Editor, call a public function to confirm everything is working:

```sql
-- Should return an empty array (no orgs yet)
select public.list_my_organizations();
```

If the function exists and returns without error, SMTA is deployed.

## 5. Add Your App Schema

Create your `app` schema tables on top of SMTA. SMTA's RLS policies gate visibility by org/unit membership — your tables reference `core.organizations` or `core.units` as needed.

```sql
create schema if not exists app;

create table app.projects (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references core.organizations(id),
  name text not null,
  created_at timestamptz default now()
);

-- Enable RLS
alter table app.projects enable row level security;

-- Only members of the org can see the project
create policy "org members" on app.projects
  for all using (
    exists (
      select 1 from core.memberships m
      where m.org_id = app.projects.org_id
        and m.user_id = core.get_current_user_id()
        and m.deleted_at is null
    )
  );
```
```

- [ ] **Step 3.4: Create `quickstart-payload.md`**

```markdown
---
title: Quick Start — Payload CMS
description: Get SMTA running alongside a Payload CMS project.
---

## 1. Prerequisites

A Payload CMS v3 project connected to a PostgreSQL database.

## 2. Generate and Apply the SQL

```bash
npm run build:payload
```

Apply the generated script to your Payload project's database:

```bash
psql "$DATABASE_URL" -f output/SMTA-payload-<timestamp>.sql
```

## 3. What the Payload Adapter Provides

The Payload deployment includes one adapter-specific file on top of `@smta/core`:

| File | Purpose |
|---|---|
| `auth_payload_impl.sql` | Implements `core.get_current_user_id()` using the `app.current_user_id` PostgreSQL session variable |

Payload CMS does not use Supabase Vault — the `core.store_secret_impl()` and `core.delete_secret_impl()` stubs remain as no-ops unless you implement your own secret storage.

## 4. Set the Session Variable in Payload Middleware

SMTA's RLS policies call `core.get_current_user_id()` on every query. For Payload, this function reads a session variable that your application must set at the start of each request:

```typescript
// In your Payload server middleware (e.g., server.ts or a beforeOperation hook)
import { Pool } from 'pg'

// Before running any Payload operation that touches the database:
await pool.query(`set local app.current_user_id = '${currentUserId}'`)
```

This must be set within the same database transaction that Payload uses for the request.

## 5. Verify

```sql
-- Set the session variable to a known user ID
set app.current_user_id = 'your-user-uuid-here';

-- Should return an empty array (no orgs yet for this user)
select public.list_my_organizations();
```

## 6. Add Your App Schema

Same as the Supabase quick start — create your `app` schema tables referencing `core.organizations` or `core.units`, enable RLS, and write policies that call `core.get_current_user_id()`.
```

- [ ] **Step 3.5: Commit**

```bash
git add apps/docs/src/content/docs/getting-started/
git commit -m "docs: add Getting Started section"
```

---

## Task 4: Architecture Section

**Files:**
- Create: `apps/docs/src/content/docs/architecture/overview.md`
- Create: `apps/docs/src/content/docs/architecture/schema-boundaries.md`
- Create: `apps/docs/src/content/docs/architecture/tenant-isolation.md`
- Create: `apps/docs/src/content/docs/architecture/adapter-pattern.md`

- [ ] **Step 4.1: Create `overview.md`**

```markdown
---
title: Architecture Overview
description: The 25,000 ft view of how SMTA is organized.
---

SMTA sits between your authentication platform and your application tables. It is a purely PostgreSQL solution — no servers, no daemons, no runtime processes. It runs inside your existing database as a set of schemas, tables, functions, and RLS policies.

## The Layered Design

```
┌─────────────────────────────────────────────────────┐
│  Application Layer                                   │
│  Your app schema: projects, posts, documents, etc.   │
│  Accessed via your DAL (CASL, Drizzle, Payload)      │
├─────────────────────────────────────────────────────┤
│  SMTA Layer                                          │
│  core + platform schemas                             │
│  Orgs, units, memberships, roles, audit, billing     │
│  Accessed via public.* SQL functions                 │
├─────────────────────────────────────────────────────┤
│  Platform Layer                                      │
│  Authentication adapter: Supabase or Payload CMS     │
└─────────────────────────────────────────────────────┘
```

## Core Concept: Membership as the Gate

SMTA's central question is: *"Is this user a member of the requested organization or unit?"*

This is enforced at the database level by PostgreSQL Row-Level Security policies. No query can bypass them — not even from your application code. The RLS policies call `core.get_current_user_id()` on every row evaluation, and the result is the authenticated user's ID as provided by the active adapter.

## Tenant Hierarchy

```
Organization (top-level tenant)
└── Unit (sub-group: team, department, project)
    └── Member (user with a role)
```

A user can belong to multiple organizations and multiple units within each organization. Roles are scoped per organization, not globally.

## The Public Interface

All client-callable operations go through `public.*` SQL functions. Client code never reads or writes SMTA tables directly — it calls functions. This gives SMTA a clear, auditable API boundary and prevents accidental exposure of internal tables.

## Monorepo Package Structure

```
packages/
├── core/       Adapter-agnostic SQL: schemas, tables, RLS, triggers, public functions
├── supabase/   Supabase-specific: JWT auth impl, Vault secrets, auth.users FK constraints
├── payload/    Payload-specific: session-variable auth impl
├── billing/    TypeScript BillingProvider interface + Stripe + Lemon Squeezy implementations
└── schemas/    Zod v4 schemas for all public.* RPC function inputs and outputs
```
```

- [ ] **Step 4.2: Create `schema-boundaries.md`**

```markdown
---
title: Schema Boundaries
description: How SMTA segments functionality across PostgreSQL schemas.
---

SMTA uses five PostgreSQL schemas to enforce security boundaries and separate concerns. Direct table access from the `public` schema is removed — all activity is routed through `public.*` functions.

## `core` Schema

The heart of SMTA. Contains:

- **`core.users`** — mirrors your auth provider's user records
- **`core.organizations`** — top-level tenants
- **`core.units`** — sub-groups within organizations
- **`core.memberships`** — links users to organizations
- **`core.unit_memberships`** — links users to units
- **`core.roles`** — named roles scoped per organization
- **`core.invitations`** — pending invitations to join an organization
- **`core.audit_logs`** — immutable record of data changes
- **`core.files`** — file metadata scoped to organizations
- **`core.tenant_secrets`** — per-tenant secret references

RLS is enabled on all `core` tables. Policies use `core.get_current_user_id()` to determine the authenticated user.

## `platform` Schema

Service-role-only tables for SaaS-wide management. Application code cannot read or write `platform` tables — only database service roles (your backend, not your end users) can access them.

Contains:
- **`platform.plans`** — subscription plan definitions
- **`platform.products`** — billable products
- **`platform.subscriptions`** — org-level subscription records
- **`platform.billing_events`** — webhook and billing lifecycle events
- **`platform.feature_flags`** — org-level feature overrides
- **`platform.org_overrides`** — admin overrides per organization

## `utils` Schema

Shared utility functions used across all schemas. Contains helpers for soft deletion, timestamp management, and audit log insertion. Not called directly by client code.

## `public` Schema

The RPC interface. Contains only functions — no tables. These are the only entry points for client code. In Supabase, PostgREST exposes them automatically as REST endpoints. In Payload, you call them via your database client.

See the [Public RPC Reference](/rpc-reference/organizations/) for all available functions.

## `app` Schema

Not created by SMTA — this is your domain. You define your application tables here and write RLS policies that reference `core` tables and call `core.get_current_user_id()`. SMTA's RLS enforcement cascades into your app schema through the session context.
```

- [ ] **Step 4.3: Create `tenant-isolation.md`**

```markdown
---
title: Tenant Isolation & RLS
description: How SMTA uses PostgreSQL Row-Level Security to enforce tenant boundaries.
---

## How RLS Works in SMTA

PostgreSQL Row-Level Security (RLS) attaches policies directly to tables. When a query hits a table with RLS enabled, PostgreSQL evaluates the policy for every row before returning it. Rows that fail the policy are silently excluded — the query returns fewer rows, not an error.

SMTA enables RLS on all `core` tables and writes policies that call `core.get_current_user_id()` to identify the authenticated user.

## The Membership Check

The canonical RLS pattern in SMTA is:

```sql
create policy "org members only" on core.some_table
  for select using (
    exists (
      select 1 from core.memberships m
      where m.org_id = core.some_table.org_id
        and m.user_id = core.get_current_user_id()
        and m.deleted_at is null
    )
  );
```

This pattern appears across all org-scoped tables. A user sees a row only if they are an active member of that row's organization.

## `core.get_current_user_id()`

This function is the keystone of SMTA's RLS system. Every policy calls it. It returns the UUID of the currently authenticated user. The implementation is adapter-specific:

- **Supabase adapter:** calls `auth.uid()`, which reads the user ID from the validated Supabase JWT
- **Payload adapter:** reads the `app.current_user_id` PostgreSQL session variable, which your middleware sets at the start of each request

Because RLS policies reference the function by name rather than by body, switching adapters requires only replacing the function implementation — the policies themselves don't change.

## Platform Lockdown

The `platform` schema is locked down by an additional layer of RLS that restricts access to the database service role. End users and application code running under the authenticated role cannot read or write `platform` tables at all.

## Soft Deletion and RLS

SMTA uses soft deletion throughout — records have a `deleted_at` column. RLS policies filter out soft-deleted rows automatically. This means:

- Deleted organizations and memberships are invisible to queries
- Data is recoverable by a service-role admin query
- Audit logs are never soft-deleted — they are append-only

## Your App Schema

SMTA's RLS extends naturally into your `app` schema. You write your own policies that follow the same pattern:

```sql
alter table app.your_table enable row level security;

create policy "org members" on app.your_table
  for all using (
    exists (
      select 1 from core.memberships m
      where m.org_id = app.your_table.org_id
        and m.user_id = core.get_current_user_id()
        and m.deleted_at is null
    )
  );
```
```

- [ ] **Step 4.4: Create `adapter-pattern.md`**

```markdown
---
title: Adapter Pattern
description: How SMTA separates adapter-agnostic core SQL from platform-specific implementations.
---

## The Problem

SMTA's RLS policies need to know who the current user is. But "who is the current user" is answered differently by Supabase (JWT) and Payload CMS (session variable). Without an abstraction, the core SQL would be littered with Supabase-specific calls.

## The Solution: Function Stubs

`@smta/core` defines a stub function:

```sql
create or replace function core.get_current_user_id()
returns uuid language sql stable security definer as $$
  select null::uuid
$$;
```

This stub always returns `null`. Every RLS policy in `@smta/core` calls this function. The stub is replaced by the adapter implementation after core deploys.

A second pair of stubs handles secret storage:

```sql
create or replace function core.store_secret_impl(p_name text, p_secret text)
returns uuid language sql as $$ select null::uuid $$;

create or replace function core.delete_secret_impl(p_secret_id uuid)
returns void language sql as $$ select $$;
```

## Adapter Implementations

**Supabase adapter** (`@smta/supabase`) replaces all three stubs:

```sql
-- auth_supabase_impl.sql
create or replace function core.get_current_user_id()
returns uuid language sql stable security definer as $$
  select auth.uid()
$$;

-- secrets_supabase_impl.sql
create or replace function core.store_secret_impl(p_name text, p_secret text)
returns uuid language sql security definer as $$
  select vault.create_secret(p_secret, p_name)
$$;
```

**Payload adapter** (`@smta/payload`) replaces only the auth stub:

```sql
-- auth_payload_impl.sql
create or replace function core.get_current_user_id()
returns uuid language sql stable security definer as $$
  select nullif(current_setting('app.current_user_id', true), '')::uuid
$$;
```

The secret stubs remain as no-ops for Payload unless you implement your own vault.

## Deployment Order

The combined SQL scripts always deploy in this order:

```
1. @smta/core    — deploys stubs + all core SQL
2. @smta/<adapter> — replaces stubs with real implementations
```

This ordering is safe because PostgreSQL resolves function calls by name at runtime, not at definition time. RLS policies defined during step 1 will call the real implementation defined in step 2 as soon as step 2 completes.

## Package Boundaries

| Package | Contains |
|---|---|
| `@smta/core` | All adapter-agnostic SQL (56 files) |
| `@smta/supabase` | Auth + secrets impl + auth.users FK constraints (3 files) |
| `@smta/payload` | Auth impl only (1 file) |
```

- [ ] **Step 4.5: Commit**

```bash
git add apps/docs/src/content/docs/architecture/
git commit -m "docs: add Architecture section"
```

---

## Task 5: Adapters Section

**Files:**
- Create: `apps/docs/src/content/docs/adapters/supabase.md`
- Create: `apps/docs/src/content/docs/adapters/payload.md`

- [ ] **Step 5.1: Create `adapters/supabase.md`**

```markdown
---
title: Supabase Adapter
description: What the @smta/supabase adapter provides and how to configure it.
---

The `@smta/supabase` adapter wires SMTA's auth interface to Supabase's JWT system and Vault secrets, and restores `auth.users` foreign keys to SMTA's user tables.

## What It Contains

| File | Purpose |
|---|---|
| `auth_supabase_impl.sql` | Implements `core.get_current_user_id()` via `auth.uid()` |
| `secrets_supabase_impl.sql` | Implements `core.store_secret_impl()` and `core.delete_secret_impl()` via Supabase Vault |
| `constraints.sql` | Adds foreign keys from `core.users`, `core.memberships`, etc. to `auth.users` |

## Auth Implementation

```sql
create or replace function core.get_current_user_id()
returns uuid language sql stable security definer as $$
  select auth.uid()
$$;
```

Supabase validates the JWT and sets `auth.uid()` for every authenticated request. SMTA's RLS policies call `core.get_current_user_id()`, which returns that value. No session setup is required in your application code.

## Secrets Implementation

SMTA routes per-tenant secret storage through Supabase Vault:

```sql
-- Store a secret and return its Vault UUID
select public.create_secret(
  p_org_id := 'your-org-uuid',
  p_name   := 'stripe_secret_key',
  p_secret := 'sk_live_...'
);
```

Secrets are stored encrypted in Vault and referenced by UUID in `core.tenant_secrets`. The plaintext is never stored in SMTA tables.

## Foreign Key Constraints

The `constraints.sql` file adds:

```sql
alter table core.users
  add constraint users_id_fkey
  foreign key (id) references auth.users(id) on delete cascade;
```

Similar constraints are added for `core.memberships` and other tables that reference user IDs. These constraints ensure referential integrity with Supabase's auth system and cascade deletes when a user is removed from Supabase Auth.

## PostgREST Exposure

Supabase auto-exposes all `public.*` functions via PostgREST. From your frontend or backend, call them as HTTP endpoints:

```typescript
const { data, error } = await supabase.rpc('list_my_organizations')
```

## Deployment

```bash
npm run build:supabase
# → output/SMTA-supabase-<timestamp>.sql  (59 files)
```
```

- [ ] **Step 5.2: Create `adapters/payload.md`**

```markdown
---
title: Payload CMS Adapter
description: What the @smta/payload adapter provides and how to configure it.
---

The `@smta/payload` adapter wires SMTA's auth interface to Payload CMS's session context via a PostgreSQL session variable, allowing SMTA to run alongside Payload without interfering with Payload's own data layer.

## What It Contains

| File | Purpose |
|---|---|
| `auth_payload_impl.sql` | Implements `core.get_current_user_id()` via the `app.current_user_id` session variable |

## Auth Implementation

```sql
create or replace function core.get_current_user_id()
returns uuid language sql stable security definer as $$
  select nullif(current_setting('app.current_user_id', true), '')::uuid
$$;
```

Unlike Supabase, Payload does not set a database-level session variable automatically. Your application middleware must set it:

```typescript
// Set before any SMTA-guarded query in the same transaction
await db.execute(sql`set local app.current_user_id = ${userId}`)
```

`set local` scopes the variable to the current transaction, which is the correct behavior for per-request isolation.

## Secrets

The Payload adapter does not implement `core.store_secret_impl()` or `core.delete_secret_impl()`. These remain as no-op stubs. If you need per-tenant secret storage under Payload, implement the stubs using your preferred secret manager (AWS Secrets Manager, HashiCorp Vault, etc.).

## Schema Compatibility

Payload CMS manages its own tables (typically in the `public` schema). SMTA uses `core`, `platform`, `utils`, and `public` (functions only — no tables). These schemas do not overlap. Payload's collections and SMTA's tenant infrastructure coexist without conflict.

## Calling Public Functions from Payload

From your Payload collection hooks or route handlers, call SMTA functions via your database client:

```typescript
const { rows } = await db.execute(
  sql`select * from public.list_my_organizations()`
)
```

## Deployment

```bash
npm run build:payload
# → output/SMTA-payload-<timestamp>.sql  (57 files)
```
```

- [ ] **Step 5.3: Commit**

```bash
git add apps/docs/src/content/docs/adapters/
git commit -m "docs: add Adapters section"
```

---

## Task 6: Public RPC Reference

**Files:**
- Create: `apps/docs/src/content/docs/rpc-reference/organizations.md`
- Create: `apps/docs/src/content/docs/rpc-reference/units.md`
- Create: `apps/docs/src/content/docs/rpc-reference/user-profile.md`
- Create: `apps/docs/src/content/docs/rpc-reference/invitations.md`
- Create: `apps/docs/src/content/docs/rpc-reference/files.md`
- Create: `apps/docs/src/content/docs/rpc-reference/secrets.md`
- Create: `apps/docs/src/content/docs/rpc-reference/audit.md`
- Create: `apps/docs/src/content/docs/rpc-reference/products.md`

- [ ] **Step 6.1: Create `rpc-reference/organizations.md`**

```markdown
---
title: Organizations
description: Public RPC functions for managing organizations (top-level tenants).
---

Organizations are the top-level tenants in SMTA. Every user belongs to one or more organizations, and all tenant-scoped data is anchored to an organization.

## `public.list_my_organizations()`

Returns all organizations the current user is an active member of.

**Returns:** `SETOF core.organizations`

```sql
select * from public.list_my_organizations();
```

## `public.get_organization(p_id UUID)`

Returns a single organization by ID. Returns nothing if the current user is not a member.

**Parameters:**
- `p_id` — organization UUID

```sql
select * from public.get_organization('org-uuid-here');
```

## `public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)`

Creates a new organization. The calling user becomes its first Super Admin member.

**Parameters:**
- `p_name` — organization display name
- `p_description` — optional description

```sql
select public.create_organization('Acme Corp', 'Our main tenant');
```

## `public.update_organization(p_id UUID, ...)`

Updates organization fields. Caller must be a Super Admin of the organization.

## `public.update_organization_meta(p_id UUID, ...)`

Updates organization metadata (custom key-value pairs). Caller must be a Super Admin.

## `public.delete_organization(p_id UUID)`

Soft-deletes an organization and all its memberships. Caller must be a Super Admin.

## `public.list_organization_members(p_id UUID)`

Lists all active members of an organization with their roles.

**Parameters:**
- `p_id` — organization UUID

## `public.get_user_role(p_org_id UUID)`

Returns the current user's role within a specific organization.

## `public.add_member_to_organization(p_org_id UUID, p_user_id UUID, p_role_id UUID)`

Adds a user to an organization with a specified role. Service-role operation.

## `public.update_member_role(p_org_id UUID, p_user_id UUID, p_role_id UUID)`

Updates an existing member's role within an organization.

## `public.remove_member_from_organization(p_org_id UUID, p_user_id UUID)`

Soft-removes a user from an organization (sets `deleted_at`).

## `public.transfer_super_admin(p_org_id UUID, p_new_super_admin_user_id UUID)`

Transfers Super Admin status to another member. The calling user must be the current Super Admin.

## `public.invite_user_to_organization(p_email TEXT, p_role_id UUID)`

Creates an invitation for a user to join the current user's organization. See [Invitations](/rpc-reference/invitations/).

## `public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)`

Removes a user from an organization. Must be called by a Super Admin or the user themselves.
```

- [ ] **Step 6.2: Create `rpc-reference/units.md`**

```markdown
---
title: Units
description: Public RPC functions for managing units (sub-groups within organizations).
---

Units are sub-groups within an organization — teams, departments, projects, or any subdivision that requires its own membership scope.

## `public.list_my_units()`

Returns all units the current user is an active member of.

```sql
select * from public.list_my_units();
```

## `public.list_units(p_org_id UUID)`

Lists all units within an organization. Caller must be a member of the organization.

## `public.get_unit(p_id UUID)`

Returns a single unit by ID. Returns nothing if the caller is not a member.

## `public.create_unit(p_org_id UUID, p_name TEXT, ...)`

Creates a new unit within an organization. Caller must be a member of the organization.

## `public.update_unit(p_id UUID, ...)`

Updates unit fields. Caller must be an admin of the unit or a Super Admin of its organization.

## `public.delete_unit(p_id UUID)`

Soft-deletes a unit. Caller must be a Super Admin of the organization.

## `public.list_unit_members(p_unit_id UUID)`

Lists all active members of a unit with their roles.

## `public.assign_user_to_unit(p_user_id UUID, p_unit_id UUID, p_role_id UUID)`

Adds a user to a unit with a specified role.

## `public.add_member_to_unit(p_unit_id UUID, p_user_id UUID, p_role_id UUID)`

Alternate form of `assign_user_to_unit`. Adds a user to a unit.

## `public.update_unit_member_role(p_unit_id UUID, p_user_id UUID, p_role_id UUID)`

Updates an existing unit member's role.

## `public.remove_user_from_unit(p_user_id UUID, p_unit_id UUID)`

Soft-removes a user from a unit.

## `public.remove_member_from_unit(p_unit_id UUID, p_user_id UUID)`

Alternate form of `remove_user_from_unit`.
```

- [ ] **Step 6.3: Create `rpc-reference/user-profile.md`**

```markdown
---
title: User Profile
description: Public RPC functions for reading and updating the current user's profile.
---

## `public.get_user_profile()`

Returns the current user's profile from `core.users`.

```sql
select * from public.get_user_profile();
```

## `public.update_user_profile(...)`

Updates the current user's profile fields (display name, avatar URL, etc.).

## `public.get_user_organizations()`

Returns all organizations the current user belongs to. Equivalent to `list_my_organizations()` — prefer `list_my_organizations()` for consistency.

## `public.get_user_units(p_org_id UUID)`

Returns all units the current user belongs to within a specific organization.

**Parameters:**
- `p_org_id` — organization UUID to scope the query
```

- [ ] **Step 6.4: Create `rpc-reference/invitations.md`**

```markdown
---
title: Invitations
description: Public RPC functions for managing organization invitations.
---

Invitations allow existing members to invite users by email. The invited user receives a token they use to accept the invitation and join the organization.

## `public.create_invitation(p_email TEXT, p_role_id UUID, ...)`

Creates an invitation for the given email address to join an organization. Caller must be a member with invitation privileges.

**Returns:** The created invitation record including the invitation token.

```sql
select public.create_invitation(
  p_email   := 'newuser@example.com',
  p_role_id := 'role-uuid-here'
);
```

## `public.accept_invitation(p_token TEXT, ...)`

Accepts an invitation using its token. Creates the membership and marks the invitation as accepted.

```sql
select public.accept_invitation('invitation-token-here');
```

## `public.cancel_invitation(p_invitation_id UUID)`

Cancels a pending invitation. Caller must be the inviter or a Super Admin.

## `public.resend_invitation(p_invitation_id UUID)`

Re-sends the invitation (resets the token expiry). Caller must be the inviter or a Super Admin.

## `public.list_invitations(p_org_id UUID)`

Lists all pending invitations for an organization.

## `public.get_invitation_details(p_token TEXT)`

Returns invitation details by token. Used to display the invitation acceptance UI before the user is logged in.
```

- [ ] **Step 6.5: Create `rpc-reference/files.md`**

```markdown
---
title: Files
description: Public RPC functions for managing file metadata scoped to organizations.
---

SMTA tracks file metadata (not file contents) in `core.files`. Files are scoped to an organization. Actual file storage is handled by your platform (Supabase Storage, S3, Cloudflare R2, etc.).

## `public.create_file(p_org_id UUID, p_name TEXT, p_url TEXT, ...)`

Records a file reference scoped to an organization.

```sql
select public.create_file(
  p_org_id := 'org-uuid',
  p_name   := 'logo.png',
  p_url    := 'https://storage.example.com/logo.png'
);
```

## `public.get_file(p_file_id UUID)`

Returns a file record by ID. Returns nothing if the caller is not a member of the file's organization.

## `public.list_files(p_org_id UUID)`

Lists all non-deleted file records for an organization.

## `public.update_file_metadata(p_file_id UUID, ...)`

Updates file metadata fields (name, URL, etc.).

## `public.delete_file(p_file_id UUID)`

Soft-deletes a file record.
```

- [ ] **Step 6.6: Create `rpc-reference/secrets.md`**

```markdown
---
title: Secrets
description: Public RPC functions for managing per-tenant secrets.
---

SMTA provides per-tenant secret storage via `core.tenant_secrets`. The secret value is stored by the adapter's secret implementation (Supabase Vault for the Supabase adapter). SMTA tables store only the secret's name and a reference ID — never the plaintext value.

## `public.create_secret(p_org_id UUID, p_name TEXT, p_secret TEXT)`

Stores a secret for an organization and returns its reference UUID.

```sql
select public.create_secret(
  p_org_id := 'org-uuid',
  p_name   := 'stripe_secret_key',
  p_secret := 'sk_live_...'
);
```

The secret value is passed to `core.store_secret_impl()` (adapter-specific). The returned UUID is stored in `core.tenant_secrets` and can be used later to retrieve or delete the secret via the adapter's native API.

## `public.list_secrets(p_org_id UUID)`

Lists all secret records for an organization. Returns names and reference IDs only — not the secret values.

## `public.delete_secret(p_secret_id UUID)`

Deletes a secret record and calls `core.delete_secret_impl()` to remove it from the adapter's secret store.

:::caution
Secret retrieval (reading the plaintext value) is not exposed via `public.*` functions. Use your adapter's native API (e.g., Supabase Vault's `vault.decrypted_secrets` view) to retrieve secret values in server-side code only.
:::
```

- [ ] **Step 6.7: Create `rpc-reference/audit.md`**

```markdown
---
title: Audit
description: Public RPC function for reading the organization audit log.
---

SMTA automatically records changes to core tables in `core.audit_logs`. The audit log is append-only — records are never updated or deleted.

## `public.get_audit_log(p_org_id UUID, p_limit INT)`

Returns recent audit log entries for an organization, newest first.

**Parameters:**
- `p_org_id` — organization UUID
- `p_limit` — maximum number of records to return

```sql
select * from public.get_audit_log(
  p_org_id := 'org-uuid',
  p_limit  := 100
);
```

**Returns columns:**
- `id` — log entry UUID
- `org_id` — organization the event belongs to
- `user_id` — user who performed the action
- `table_name` — which core table was changed
- `action` — `INSERT`, `UPDATE`, or `DELETE`
- `old_data` — JSON snapshot of the row before the change (null for INSERT)
- `new_data` — JSON snapshot of the row after the change (null for DELETE)
- `created_at` — when the event occurred

## What Is Audited

SMTA installs triggers on the following tables that write to `core.audit_logs` automatically:

- `core.organizations`
- `core.units`
- `core.memberships`
- `core.unit_memberships`
- `core.roles`
- `core.invitations`

No application code changes are required — auditing is handled entirely at the database level.
```

- [ ] **Step 6.8: Create `rpc-reference/products.md`**

```markdown
---
title: Products
description: Public RPC function for listing available subscription products.
---

SMTA exposes the subscription products defined in `platform.products` through a single public function. Product management (creating, updating plans and products) is done via service-role access to the `platform` schema, typically from your billing webhook handler.

## `public.list_subscription_products()`

Returns all active subscription products and their associated plans.

```sql
select * from public.list_subscription_products();
```

**Returns:** Each row represents a product with its pricing plan details — name, interval (monthly/annual), price, currency, and external processor ID (Stripe price ID or Lemon Squeezy variant ID).

## Integration with Billing

Products and plans are populated by your billing provider integration. See the [Billing Integration](/billing/overview/) section for how Stripe and Lemon Squeezy sync product data into `platform.products` and `platform.plans`.
```

- [ ] **Step 6.9: Commit**

```bash
git add apps/docs/src/content/docs/rpc-reference/
git commit -m "docs: add Public RPC Reference section"
```

---

## Task 7: Billing Section

**Files:**
- Create: `apps/docs/src/content/docs/billing/overview.md`
- Create: `apps/docs/src/content/docs/billing/stripe.md`
- Create: `apps/docs/src/content/docs/billing/lemon-squeezy.md`

- [ ] **Step 7.1: Create `billing/overview.md`**

```markdown
---
title: Billing Integration Overview
description: How SMTA integrates with payment processors via the BillingProvider interface.
---

SMTA's billing integration lives in `@smta/billing`, a TypeScript package that provides a `BillingProvider` interface with two implementations: Stripe and Lemon Squeezy.

## How It Works

```
Payment Processor (Stripe / Lemon Squeezy)
        ↓  webhooks
BillingProvider implementation
        ↓  writes to
platform.products, platform.plans, platform.subscriptions, platform.billing_events
        ↓  read by
public.list_subscription_products()
```

1. Your payment processor sends webhook events to your backend.
2. Your backend passes events to the `BillingProvider` implementation.
3. The provider syncs product, plan, and subscription data into `platform.*` tables.
4. Client code reads available products via `public.list_subscription_products()`.
5. Org-level subscription status is stored in `platform.subscriptions`.

## BillingProvider Interface

```typescript
import { BillingProvider } from '@smta/billing'

interface BillingProvider {
  handleWebhook(event: RawWebhookEvent): Promise<void>
  createCheckoutSession(params: CheckoutParams): Promise<CheckoutSession>
  cancelSubscription(subscriptionId: string): Promise<void>
  getSubscription(subscriptionId: string): Promise<Subscription>
}
```

Choose your implementation at startup — it's a TypeScript import, not a database setting:

```typescript
import { StripeProvider } from '@smta/billing/stripe'
// or
import { LemonSqueezyProvider } from '@smta/billing/lemon-squeezy'
```

## Database Tables

| Table | Purpose |
|---|---|
| `platform.products` | Billable products synced from your payment processor |
| `platform.plans` | Pricing plans (monthly, annual) per product |
| `platform.subscriptions` | Active subscriptions linked to organizations |
| `platform.billing_events` | Raw webhook event log for debugging and replay |

All `platform.*` tables require service-role access — end users cannot read them directly.
```

- [ ] **Step 7.2: Create `billing/stripe.md`**

```markdown
---
title: Stripe Integration
description: Using @smta/billing with Stripe.
---

## Installation

```bash
pnpm add @smta/billing stripe
```

## Setup

```typescript
import { StripeProvider } from '@smta/billing/stripe'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY)
const billing = new StripeProvider({ stripe, db })
```

## Webhook Handler

Wire up your Stripe webhook endpoint to call `handleWebhook`:

```typescript
// POST /webhooks/stripe
app.post('/webhooks/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature']
  const event = stripe.webhooks.constructEvent(
    req.body,
    sig,
    process.env.STRIPE_WEBHOOK_SECRET
  )
  await billing.handleWebhook(event)
  res.json({ received: true })
})
```

The `StripeProvider` handles the following Stripe event types automatically:

- `product.created`, `product.updated`, `product.deleted` — syncs to `platform.products`
- `price.created`, `price.updated` — syncs to `platform.plans`
- `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted` — syncs to `platform.subscriptions`

## Creating a Checkout Session

```typescript
const session = await billing.createCheckoutSession({
  orgId: 'org-uuid',
  priceId: 'price_stripe_id',
  successUrl: 'https://app.example.com/billing/success',
  cancelUrl: 'https://app.example.com/billing/cancel',
})

// Redirect the user to session.url
```

## Required Stripe Configuration

- Enable webhooks for the events listed above in your Stripe Dashboard
- Set `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` environment variables
- Link subscriptions to org IDs using Stripe's `metadata.org_id` field (the `StripeProvider` reads this automatically)
```

- [ ] **Step 7.3: Create `billing/lemon-squeezy.md`**

```markdown
---
title: Lemon Squeezy Integration
description: Using @smta/billing with Lemon Squeezy.
---

## Installation

```bash
pnpm add @smta/billing @lemonsqueezy/lemonsqueezy.js
```

## Setup

```typescript
import { LemonSqueezyProvider } from '@smta/billing/lemon-squeezy'
import { lemonSqueezySetup } from '@lemonsqueezy/lemonsqueezy.js'

lemonSqueezySetup({ apiKey: process.env.LEMON_SQUEEZY_API_KEY })
const billing = new LemonSqueezyProvider({ db })
```

## Webhook Handler

```typescript
// POST /webhooks/lemon-squeezy
app.post('/webhooks/lemon-squeezy', express.json(), async (req, res) => {
  // Verify the webhook signature
  const secret = process.env.LEMON_SQUEEZY_WEBHOOK_SECRET
  const hmac = crypto.createHmac('sha256', secret)
  const digest = hmac.update(JSON.stringify(req.body)).digest('hex')
  if (digest !== req.headers['x-signature']) {
    return res.status(401).json({ error: 'Invalid signature' })
  }

  await billing.handleWebhook(req.body)
  res.json({ received: true })
})
```

The `LemonSqueezyProvider` handles:

- `product_created`, `product_updated` — syncs to `platform.products`
- `variant_created`, `variant_updated` — syncs to `platform.plans` (Lemon Squeezy variants map to plans)
- `subscription_created`, `subscription_updated`, `subscription_cancelled` — syncs to `platform.subscriptions`

## Creating a Checkout Session

```typescript
const session = await billing.createCheckoutSession({
  orgId: 'org-uuid',
  variantId: 'lemon-squeezy-variant-id',
  successUrl: 'https://app.example.com/billing/success',
})

// Redirect the user to session.url
```

## Required Lemon Squeezy Configuration

- Enable webhooks for the events listed above in your Lemon Squeezy store settings
- Set `LEMON_SQUEEZY_API_KEY` and `LEMON_SQUEEZY_WEBHOOK_SECRET` environment variables
- Add `org_id` as a custom field in your Lemon Squeezy checkout to link subscriptions to organizations
```

- [ ] **Step 7.4: Commit**

```bash
git add apps/docs/src/content/docs/billing/
git commit -m "docs: add Billing Integration section"
```

---

## Task 8: Testing and Contributing Sections

**Files:**
- Create: `apps/docs/src/content/docs/testing/setup.md`
- Create: `apps/docs/src/content/docs/testing/running.md`
- Create: `apps/docs/src/content/docs/contributing/package-structure.md`
- Create: `apps/docs/src/content/docs/contributing/adding-sql.md`
- Create: `apps/docs/src/content/docs/contributing/test-conventions.md`

- [ ] **Step 8.1: Create `testing/setup.md`**

```markdown
---
title: Test Setup
description: Prerequisites for running the SMTA test suite.
---

SMTA uses [pgTap](https://pgtap.org/) for database-level testing. pgTap runs SQL assertions directly in PostgreSQL, so tests are executed against a real database — no mocking.

## Prerequisites

### 1. PostgreSQL

A running PostgreSQL instance (version 14+). Locally, install via your OS package manager or use Docker:

```bash
docker run -d \
  --name smta-test-db \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgres:16
```

### 2. pgTap Extension

Install pgTap into your PostgreSQL instance. On Debian/Ubuntu:

```bash
sudo apt-get install pgtap
```

On macOS with Homebrew:

```bash
brew install pgtap
```

Or build from source: https://pgtap.org/documentation.html#installation

Enable the extension in your test database:

```sql
create extension if not exists pgtap;
```

### 3. `pg_prove`

`pg_prove` is the test runner that invokes pgTap and collects results. It is installed with the `TAP::Parser::SourceHandler::pgTAP` Perl module:

```bash
cpan TAP::Parser::SourceHandler::pgTAP
```

Or on Ubuntu:

```bash
sudo apt-get install libtap-parser-sourcehandler-pgtap-perl
```

### 4. Environment Variables

The test script reads the following environment variables (with defaults):

| Variable | Default | Purpose |
|---|---|---|
| `PGHOST` | `localhost` | Database host |
| `PGPORT` | `5432` | Database port |
| `PGUSER` | `postgres` | Database user |
| `PGPASSWORD` | `postgres` | Database password |
| `PGDATABASE` | `smta_test` | Test database name |

Set them in your shell or in a `.env` file before running tests.

### 5. Test Database

Create the test database and apply SMTA:

```bash
createdb smta_test
npm run build:supabase
psql -d smta_test -f output/SMTA-supabase-<timestamp>.sql
psql -d smta_test -f scripts/99_testing_grants.sql
```

The `99_testing_grants.sql` file grants the permissions needed for pgTap to run as a non-superuser role.
```

- [ ] **Step 8.2: Create `testing/running.md`**

```markdown
---
title: Running the Test Suite
description: How to run SMTA's pgTap tests.
---

## Run All Tests

```bash
npm test
```

This runs `scripts/run_tests.sh`, which invokes `pg_prove` against all 35 test files in `tests/`.

Expected output (all passing):

```
tests/core/organizations.sql .. ok
tests/core/units.sql ........... ok
...
All tests successful.
Files=35, Tests=449, Xs wallclock secs
```

## Run a Single Test File

```bash
pg_prove -d smta_test tests/core/organizations.sql
```

## Test File Structure

Each test file follows this pattern:

```sql
begin;
select plan(N);  -- declare the number of assertions

-- assertions
select ok(some_condition, 'description of what is being tested');
select is(actual_value, expected_value, 'description');
select throws_ok($$select public.some_function()$$, 'expected error');

select finish();
rollback;
```

Every test file runs in a transaction that is rolled back at the end, so tests are fully isolated and can be run in any order.

## Test Coverage

The 449 tests cover:

- Schema existence and column types
- RLS policy enforcement (unauthorized access returns no rows)
- `public.*` function behavior (correct returns, error cases)
- Soft deletion (deleted records are invisible to normal queries)
- Audit log population (changes trigger audit entries)
- Adapter stub behavior

## Adding Tests

See [Test Conventions](/contributing/test-conventions/) for guidelines on writing new tests.
```

- [ ] **Step 8.3: Create `contributing/package-structure.md`**

```markdown
---
title: Package Structure
description: How the SMTA monorepo is organized and what each package contains.
---

SMTA is a pnpm monorepo managed with Turborepo. Each package has a single responsibility.

## Packages

```
packages/
├── core/       @smta/core      — 56 SQL files: all adapter-agnostic SMTA schema
├── supabase/   @smta/supabase  — 3 SQL files: Supabase auth/secrets impl + FK constraints
├── payload/    @smta/payload   — 1 SQL file: Payload auth impl + TypeScript middleware
├── billing/    @smta/billing   — TypeScript BillingProvider + Stripe + Lemon Squeezy
└── schemas/    @smta/schemas   — Zod v4 schemas for all public.* RPC contracts
```

## `@smta/core` SQL Layout

```
packages/core/sql/
├── init/
│   ├── schemas.sql              — create schemas
│   ├── extensions.sql           — pg extensions
│   └── auth_interface.sql       — core.get_current_user_id() stub
├── platform/
│   ├── tables/                  — 13 platform table files
│   ├── functions/               — 10 platform function files
│   └── rls/                     — platform RLS lockdown
├── core/
│   ├── tables/                  — core table files (users, orgs, memberships, etc.)
│   ├── triggers/                — audit and soft-delete triggers
│   └── rls/                     — core RLS policies
├── public/
│   └── functions/               — 8 public.* function group files
└── utils/
    └── functions/               — shared utility functions
```

## `sql-scripts.json` Manifests

Each package has a `sql-scripts.json` that defines the execution order of its SQL files:

```json
{
  "version": "1.0",
  "description": "...",
  "scripts": [
    "sql/init/schemas.sql",
    "sql/init/extensions.sql",
    ...
  ]
}
```

The root `scripts/combine_files.js` reads these manifests and assembles the deployment script. Order within `sql-scripts.json` is critical — tables must be created before views or functions that reference them.

## apps/

```
apps/
└── docs/   @smta/docs   — This documentation site (Astro Starlight)
```

A future demo site would go in `apps/demo/`.
```

- [ ] **Step 8.4: Create `contributing/adding-sql.md`**

```markdown
---
title: Adding SQL
description: How to add new SQL files to @smta/core or adapter packages.
---

## 1. Determine the Right Package

- Adapter-agnostic SQL (works identically under Supabase and Payload) → `packages/core/`
- Supabase-specific SQL → `packages/supabase/`
- Payload-specific SQL → `packages/payload/`

## 2. Choose the Right Directory

Within `packages/core/sql/`:

| Type of SQL | Directory |
|---|---|
| Schema creation, extensions, stubs | `init/` |
| Platform tables | `platform/tables/` |
| Platform functions | `platform/functions/` |
| Core tables (users, orgs, memberships) | `core/tables/` |
| Triggers (audit, soft-delete) | `core/triggers/` |
| RLS policies for core tables | `core/rls/` |
| `public.*` functions | `public/functions/` |
| Utility functions | `utils/functions/` |

## 3. Write the SQL File

Follow the conventions of existing files in the same directory. Key conventions:

- Use `create or replace function` so the file is idempotent
- Use `create table if not exists` for tables
- Add `created_at timestamptz default now()` and `deleted_at timestamptz` to all entity tables
- Enable RLS on all new tables: `alter table schema.table enable row level security;`
- Write a corresponding RLS policy that checks org membership

## 4. Register in `sql-scripts.json`

Add your new file to the `scripts` array in the appropriate package's `sql-scripts.json`, at the correct position relative to its dependencies:

```json
{
  "scripts": [
    "sql/core/tables/existing_table.sql",
    "sql/core/tables/your_new_table.sql",   ← add here, after its dependencies
    "sql/core/rls/existing_rls.sql"
  ]
}
```

Tables must appear before functions or views that reference them. Functions must appear before triggers that call them.

## 5. Verify the Build

```bash
npm run build:supabase
npm run build:payload
```

Both builds must succeed without error. The combined SQL files are in `output/`.

## 6. Write Tests

Add a test file in `tests/` covering the new functionality. See [Test Conventions](/contributing/test-conventions/).
```

- [ ] **Step 8.5: Create `contributing/test-conventions.md`**

```markdown
---
title: Test Conventions
description: How to write pgTap tests for SMTA.
---

## File Location

Tests live in `tests/`. Mirror the source structure:

- Core table tests → `tests/core/`
- Public function tests → `tests/public/`
- RLS policy tests → `tests/rls/`
- Platform tests → `tests/platform/`

## File Template

```sql
begin;
select plan(N);  -- replace N with the exact number of assertions in this file

-- =====================
-- Setup
-- =====================
-- Insert test fixtures here (orgs, users, memberships)
-- All changes are rolled back at the end

insert into core.organizations (id, name) values
  ('org-1-uuid', 'Test Org');

-- =====================
-- Tests
-- =====================

-- Test: function exists
select has_function('public', 'your_function_name', 'public.your_function_name() exists');

-- Test: correct return value
select is(
  (select result_column from public.your_function_name()),
  'expected value',
  'your_function_name returns correct value'
);

-- Test: RLS blocks unauthorized access
set local app.current_user_id = 'non-member-uuid';
select is(
  (select count(*)::int from core.your_table where org_id = 'org-1-uuid'),
  0,
  'non-member cannot see rows'
);

-- Test: authorized member can see rows
set local app.current_user_id = 'member-uuid';
select is(
  (select count(*)::int from core.your_table where org_id = 'org-1-uuid'),
  1,
  'org member can see rows'
);

-- =====================
select finish();
rollback;
```

## Counting Assertions

The number passed to `plan(N)` must match the exact number of `select` assertions in the file. pgTap fails the test if they don't match. Count carefully.

## Testing RLS

Always test both sides of a policy:
1. A non-member (or unauthenticated user) cannot see the row
2. A member can see the row

Use `set local app.current_user_id = '...'` to simulate different users within the same test file. The `set local` scopes the change to the current transaction.

## Testing Errors

Use `throws_ok` to assert that a function raises an error under invalid input:

```sql
select throws_ok(
  $$select public.get_organization('non-existent-uuid')$$,
  null,  -- error code (null = any)
  null,  -- error message (null = any)
  'get_organization with non-existent ID raises error'
);
```

## Running Your Test

```bash
pg_prove -d smta_test tests/your_new_test.sql
```

Verify it passes before committing.
```

- [ ] **Step 8.6: Commit**

```bash
git add apps/docs/src/content/docs/testing/ apps/docs/src/content/docs/contributing/
git commit -m "docs: add Testing and Contributing sections"
```

---

## Task 9: Final Build Verification and Cloudflare Pages Setup

- [ ] **Step 9.1: Run a final production build**

```bash
pnpm --filter @smta/docs build
```

Expected: `apps/docs/dist/` contains all pages as static HTML. No build errors.

Spot-check a few pages exist:

```bash
ls apps/docs/dist/
ls apps/docs/dist/getting-started/
ls apps/docs/dist/architecture/
ls apps/docs/dist/rpc-reference/
```

- [ ] **Step 9.2: Update the GitHub URL in `astro.config.mjs`**

Before deploying, replace the placeholder GitHub URL with the real one:

In `apps/docs/astro.config.mjs`, change:
```javascript
{ icon: 'github', label: 'GitHub', href: 'https://github.com/YOUR_ORG/saasdb' },
```
To your actual GitHub repo URL.

Do the same in `apps/docs/src/content/docs/index.mdx`.

- [ ] **Step 9.3: Configure Cloudflare Pages**

In the Cloudflare dashboard → Pages → Create a project → Connect to Git:

| Setting | Value |
|---|---|
| Repository | your GitHub repo |
| Production branch | `master` |
| Build command | `pnpm --filter @smta/docs build` |
| Build output directory | `apps/docs/dist` |
| Root directory | `/` (monorepo root) |
| Node version | `20` |

After saving, Cloudflare Pages will trigger an initial build. Watch the build log — it should complete successfully.

- [ ] **Step 9.4: Add custom domain**

In Cloudflare Pages → your project → Custom domains → Add `smta.dev`. Since you're already using Cloudflare DNS, the CNAME record is added automatically.

- [ ] **Step 9.5: Commit and push to trigger deployment**

```bash
git add apps/docs/astro.config.mjs apps/docs/src/content/docs/index.mdx
git commit -m "docs: update GitHub URL in Astro config and landing page"
git push
```

Cloudflare Pages will detect the push and deploy automatically.

---

## Verification Checklist

- [ ] `pnpm --filter @smta/docs build` succeeds with no errors
- [ ] `apps/docs/dist/index.html` exists
- [ ] All 7 sidebar sections render in the browser
- [ ] `smta.dev` resolves to the Cloudflare Pages deployment
- [ ] HTTPS is active on `smta.dev`
- [ ] Each content section has at least one page with real content (no blank pages)
- [ ] The existing `npm test` (pgTap suite) still passes — the docs site must not break anything
