# SMTA Package Restructure & sql/ Elimination

**Date:** 2026-05-24  
**Status:** Approved for implementation planning

---

## Problem

Two sources of truth for SQL exist: the monolithic `sql/` tree and the `packages/` monorepo. Any schema change must be made in both places. Additionally, the current package split is wrong: platform tables, billing, RLS lockdown, and public RPC functions ended up in `@smta/supabase` even though they are pure PostgreSQL with no Supabase dependency. This means a Payload deployment cannot get the full SMTA feature set without depending on `@smta/supabase`, defeating the purpose of the adapter split.

---

## Goal

- One source of truth: `packages/` only, `sql/` deleted
- Both adapters (Supabase, Payload) deploy identical SMTA functionality (platform schema, billing, RLS, public functions)
- Adapter packages contain only the genuinely adapter-specific SQL
- `combine_files.js` assembles a combined deployment script from packages, with `--adapter` flag for target selection

---

## Correct Package Boundaries

### `@smta/core` — everything adapter-agnostic

| Section | Files |
|---|---|
| Init | `schemas.sql`, `auth_interface.sql`, `secrets_interface.sql` |
| Utils | `functions.sql` |
| Platform tables | roles, users, orgs, action_logs, settings, subscription_overrides, feature_flags, system_events, tenant_secrets, billing_customers, billing_subscriptions, subscription_products, grants (13 files) |
| Core tables | organizations, units, roles, memberships, users_meta, organization_files, organizations_meta, audit_logs, invitations, grants (10 files) |
| Core triggers | new_user, new_organization, new_unit, protect_super_admin |
| RLS | core helpers, core policies, core invitations, platform lockdown |
| Core functions | log_audit, secrets, invitations |
| Public functions | user_profile, organizations, units, files, audit, secrets, invitations, products (8 files) |
| Platform functions | log_action, users, organizations, overrides, feature_flags, events, audit, settings, billing, products (10 files) |
| App placeholder | `app/` (empty, for consumer app-specific tables) |

### `@smta/supabase` — Supabase-specific only

| Section | Files |
|---|---|
| Init | `auth_supabase_impl.sql` (JWT → `core.get_current_user_id()`), `secrets_supabase_impl.sql` (Vault) |
| Constraints | `constraints.sql` (restores `auth.users` FKs on core tables) |

### `@smta/payload` — Payload-specific only

| Section | Files |
|---|---|
| Init | `auth_payload_impl.sql` (session variable → `core.get_current_user_id()`) |

---

## Execution Order

Both adapters deploy core first, then their adapter layer on top. The stub/interface pattern makes this safe: RLS policies reference `core.get_current_user_id()` by name; the stub is replaced by the adapter impl after all core SQL is defined without any policy redefinition.

```
CORE (both adapters)
  init/schemas
  init/auth_interface          ← stub
  init/secrets_interface       ← stub
  utils/functions
  platform/tables/* (13 files, in dependency order)
  core/tables/* (10 files)
  core/triggers/*
  platform/tables/billing/* + grants
  core/rls/*
  platform/rls/lockdown
  core/functions/*
  public/functions/*
  platform/functions/*

SUPABASE ADAPTER
  init/auth_supabase_impl      ← replaces stub
  init/secrets_supabase_impl   ← replaces stub
  constraints                  ← restores auth.users FKs

PAYLOAD ADAPTER
  init/auth_payload_impl       ← replaces stub
  (no auth.users FKs, no Vault)
```

---

## Billing Provider Selection

Billing adapter choice (Stripe vs. Lemon Squeezy) is independent of the database adapter. The billing tables are deployed as part of `@smta/core`. The provider is selected at the application layer via TypeScript import:

```typescript
import { StripeProvider } from '@smta/billing';
// or
import { LemonSqueezyProvider } from '@smta/billing';
```

---

## Build Tooling Changes

### `scripts/combine_files.js`

Updated to accept `--adapter supabase|payload`. Reads two package manifests in sequence, resolves file paths relative to each package's root directory, writes a single combined SQL file to `output/`.

### `package.json` scripts

```json
"build:supabase": "node ./scripts/combine_files.js --adapter supabase",
"build:payload":  "node ./scripts/combine_files.js --adapter payload",
"build":          "npm run build:supabase && npm run build:payload"
```

### `scripts/sql-scripts.json`

Deleted. The per-package `sql-scripts.json` files replace it as the single source of execution order.

---

## Files Deleted

- `sql/` — entire directory tree
- `scripts/sql-scripts.json`

## Files Moved / Renamed

| From | To |
|---|---|
| `packages/supabase/sql/platform/` | `packages/core/sql/platform/` |
| `packages/supabase/sql/public/` | `packages/core/sql/public/` |
| `packages/core/sql/init/auth_supabase_impl.sql` | `packages/supabase/sql/init/auth_supabase_impl.sql` |
| `packages/core/sql/init/secrets_supabase_impl.sql` | `packages/supabase/sql/init/secrets_supabase_impl.sql` |
| `packages/payload/sql/auth/get_current_user_id.sql` | `packages/payload/sql/init/auth_payload_impl.sql` |

---

## Testing

No changes to `tests/`. The test suite runs against the deployed database schema and is agnostic to how that schema is deployed. After restructuring, run `./scripts/run_tests.sh` against a freshly deployed Supabase build to confirm all 449 tests pass.

---

## Resulting `packages/core/sql/` Directory Structure

```
packages/core/sql/
├── init/                    schemas, auth_interface, secrets_interface
├── utils/                   shared utility functions
├── platform/
│   ├── tables/              13 platform tables (moved from @smta/supabase)
│   ├── functions/           10 platform functions (moved from @smta/supabase)
│   └── rls/
│       └── lockdown.sql     (moved from @smta/supabase)
├── tables/                  10 core tables (unchanged)
├── triggers/                4 core triggers (unchanged)
├── functions/               3 core functions (unchanged)
├── rls/                     core RLS helpers, policies, invitations (unchanged)
├── public/
│   └── functions/           8 public RPC functions (moved from @smta/supabase)
└── app/                     placeholder for consumer app tables
```

---

## What Does NOT Change

- SQL logic inside any file (this is a file reorganization, not a schema change)
- `@smta/billing` TypeScript package
- `@smta/schemas` TypeScript package
- `packages/payload/src/` TypeScript middleware
- `tests/` directory
- `scripts/run_tests.sh`
