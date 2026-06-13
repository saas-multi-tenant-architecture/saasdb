# @smta/better-auth Integration Design

**Date:** 2026-06-12
**Status:** Approved for implementation planning

---

## Goal

Add a `@smta/better-auth` adapter package that wires better-auth's authentication layer into SMTA's multi-tenant RLS enforcement, and exposes SMTA's tenant management functions through better-auth's plugin and client SDK. The two systems co-exist without overlap: better-auth owns identity and auth ceremonies; SMTA owns data isolation and tenant structure.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  better-auth                                    │
│  OAuth · magic link · passkeys · 2FA · sessions │
└───────────────────┬─────────────────────────────┘
                    │ session (user.id, activeOrgId)
┌───────────────────▼─────────────────────────────┐
│  @smta/better-auth                              │
│  proxy.ts · withSMTA() · smtaPlugin             │
└───────┬───────────────────────┬─────────────────┘
        │ SET app.current_user_id  │ wraps public.*
        │ (per-transaction)        │ as auth.api.*
┌───────▼─────────────────────────────────────────┐
│  SMTA (core schema)                             │
│  RLS policies · organizations · memberships     │
│  units · invitations · audit · billing          │
└─────────────────────────────────────────────────┘
```

**Responsibilities:**
- better-auth: identity, credentials, sessions, OAuth tokens, 2FA, passkeys, magic link
- SMTA: tenant structure, row-level isolation, memberships, roles, invitations, billing
- `@smta/better-auth`: bridge — wires session identity into SMTA's RLS mechanism and surfaces SMTA's tenant management through better-auth's client SDK

**Stability guarantee:** the plugin depends only on SMTA's public interfaces (`core.get_current_user_id()` stub, `public.*` functions, `core.users_meta` schema) — not on internal table structure. SMTA's internals can evolve without breaking the adapter as long as those interfaces hold.

---

## UUID Requirement

better-auth must be configured to generate UUID v4 (or v7) IDs. SMTA's entire schema uses `UUID` primary and foreign keys; a non-UUID `id` in better-auth's `user` table will cause the new-user trigger to fail loudly at signup.

```typescript
export const auth = betterAuth({
  generateId: () => crypto.randomUUID(), // v4 — fine at startup
  // For high-write production, use a UUID v7 library for sequential index inserts
});
```

---

## Package Structure

```
packages/better-auth/
├── sql/
│   ├── sql-scripts.json
│   └── init/
│       ├── auth_better_auth_impl.sql   — core.get_current_user_id() implementation
│       └── new_user_trigger.sql        — trigger on better-auth's user table
├── src/
│   ├── index.ts                        — package exports
│   ├── middleware/
│   │   └── inject-user-context.ts      — withSMTA() + injectUserContext()
│   └── plugin/
│       ├── index.ts                    — smtaPlugin definition
│       ├── endpoints.ts                — SMTA public.* wrapped as auth.api.*
│       └── session.ts                  — activeOrgId session augmentation
├── package.json
├── tsconfig.json
└── README.md
```

Package name: `@smta/better-auth`
Added to `pnpm-workspace.yaml` alongside existing packages.

---

## SQL Layer

### `auth_better_auth_impl.sql`

Implements `core.get_current_user_id()` by reading a PostgreSQL session variable — identical mechanism to `@smta/payload`:

```sql
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

The `true` flag returns NULL (rather than raising an error) when the setting is absent, so unauthenticated requests get NULL and RLS blocks all rows cleanly.

### `new_user_trigger.sql`

Fires after INSERT on better-auth's `user` table and auto-creates a `core.users_meta` row — replacing the role of the `auth.users` trigger in the Supabase adapter:

```sql
CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = core
AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id::UUID, NEW.email);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_better_auth_user_created
AFTER INSERT ON "user"
FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();
```

**Notes:**
- Targets better-auth's default table name `"user"` (quoted — reserved word in PostgreSQL). If the developer configures a table prefix (e.g. `ba_user`), the trigger target must be updated to match.
- The `::UUID` cast is intentional: it fails loudly if better-auth is misconfigured to generate non-UUID IDs, surfacing the misconfiguration at signup rather than silently corrupting FK relationships downstream.

### `sql-scripts.json`

```json
{
  "files": [
    "sql/init/auth_better_auth_impl.sql",
    "sql/init/new_user_trigger.sql"
  ]
}
```

---

## TypeScript Layer

### `inject-user-context.ts`

Low-level helpers and the primary `withSMTA()` wrapper. Built on raw `pg` for maximum compatibility, mirroring `@smta/payload`'s existing pattern:

```typescript
import type { Pool, PoolClient } from 'pg';

export async function injectUserContext(
  client: PoolClient,
  userId: string
): Promise<void> {
  await client.query(
    `SELECT set_config('app.current_user_id', $1, true)`,
    [userId]
  );
}

export async function clearUserContext(client: PoolClient): Promise<void> {
  await client.query(
    `SELECT set_config('app.current_user_id', '', true)`
  );
}

export async function withSMTA<T>(
  pool: Pool,
  userId: string | null | undefined,
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (userId) await injectUserContext(client, userId);
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```

The `true` flag in `set_config` makes `app.current_user_id` transaction-local — automatically cleared on commit or rollback, preventing context leaking between requests on a pooled connection.

**ORM note:** The package uses raw `pg`. The README will include a Drizzle companion pattern (the dominant ORM choice in better-auth projects) showing how to call `set_config` within a Drizzle transaction.

### Usage in a Next.js Route Handler

```typescript
import { auth } from '@/lib/auth';
import { withSMTA } from '@smta/better-auth';
import { pool } from '@/lib/db';

export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });

  return withSMTA(pool, session?.user?.id, async (client) => {
    const { rows } = await client.query(
      'SELECT * FROM public.list_user_organizations()'
    );
    return Response.json(rows);
  });
}
```

### Next.js `proxy.ts`

The adapter does not ship a `proxy.ts` file — auth protection (redirecting unauthenticated requests) is handled by the developer using better-auth's standard Next.js proxy pattern. The README documents the recommended setup. `proxy.ts` replaced the deprecated `middleware.ts` in a post-August-2025 Next.js release; the exact API shape should be verified against current Next.js docs during implementation.

---

## better-auth Plugin

### Registration

```typescript
import { betterAuth } from 'better-auth';
import { smtaPlugin } from '@smta/better-auth';
import { pool } from '@/lib/db';

export const auth = betterAuth({
  generateId: () => crypto.randomUUID(),
  plugins: [smtaPlugin({ pool })],
});
```

The plugin receives the `pg` Pool at registration so its endpoints have a DB connection available without requiring it to be passed per-call.

### Endpoints Added to `auth.api`

Each endpoint calls `withSMTA()` internally using the session's `user.id`, so SMTA's RLS is enforced at the DB layer — the user cannot affect organizations they are not a member of regardless of what they pass in the request body.

| Plugin endpoint | Wraps SMTA function |
|---|---|
| `auth.api.smtaCreateOrganization()` | `public.create_organization()` |
| `auth.api.smtaListOrganizations()` | `public.list_my_organizations()` |
| `auth.api.smtaGetOrganization()` | `public.get_organization()` |
| `auth.api.smtaCreateInvitation()` | `public.create_invitation()` |
| `auth.api.smtaAcceptInvitation()` | `public.accept_invitation()` |
| `auth.api.smtaGetInvitationDetails()` | `public.get_invitation_details()` |
| `auth.api.smtaListInvitations()` | `public.list_invitations()` |
| `auth.api.smtaListOrgMembers()` | `public.list_organization_members()` |
| `auth.api.smtaGetUserPermissions()` | `public.get_user_permissions()` |
| `auth.api.smtaSetActiveOrg()` | writes `activeOrgId` to session |

The full `public.*` surface (unit management, billing, audit logs, platform admin) is not wrapped by the plugin — those operations belong in server-side Route Handlers using `withSMTA()` directly.

### Session Augmentation

The plugin adds one field to the better-auth session:

```typescript
session.user.activeOrgId: string | null
```

Set by the client calling `auth.api.smtaSetActiveOrg()`. Useful for multi-org users where the app needs to know which organization is currently in context.

The user's role within the active org is intentionally **not** stored in the session — it would go stale as memberships change. Role is fetched on demand via `auth.api.smtaListMemberships()` or directly via a `withSMTA()` block.

---

## Deployment

### Build command

```bash
npm run build:better-auth  # → output/SMTA-better-auth-<timestamp>.sql
```

### Deploy order (required)

1. Run better-auth's database migration — creates the `user`, `session`, `account`, `verification` tables
2. Apply `output/SMTA-better-auth-<timestamp>.sql` — requires `@smta/core` tables to already exist

The `@smta/better-auth` SQL is not standalone. It layers on top of `@smta/core` exactly as `@smta/supabase` and `@smta/payload` do.

### `pnpm-workspace.yaml` addition

```yaml
packages:
  - packages/core
  - packages/supabase
  - packages/payload
  - packages/better-auth
  - packages/billing
  - packages/schemas
```

---

## Testing

New file: `tests/adapters/06_better_auth_adapter.sql` (~10–15 pgTap tests)

**Three test areas:**

1. **`core.get_current_user_id()` implementation** — set `app.current_user_id` via `set_config`, assert the function returns the expected UUID; clear it, assert it returns NULL.

2. **New user trigger** — insert a row into better-auth's `user` table, assert `core.users_meta` row is created with matching `id` and `email`; insert a non-UUID `id`, assert the trigger raises an exception.

3. **RLS enforcement end-to-end** — set `app.current_user_id` to a user with membership in Org A, query `core.organizations`, assert only Org A is visible; switch to a user with no memberships, assert zero rows returned.

TypeScript layer (`withSMTA()`, plugin endpoints) is not tested in the pgTap suite — tested in the consuming Next.js application's test suite (Vitest or Jest), consistent with `@smta/payload`.

**Projected test count:** ~520 (up from 508 across 40 files).

---

## Out of Scope

- better-auth's built-in `organizations` plugin — not used. SMTA's organization model (units, soft delete, audit, billing, custom roles) is more capable and already has a full `public.*` API surface.
- TypeScript unit tests within the package — consistent with `@smta/payload` convention.
- Drizzle-specific wrapper — covered in README documentation, not a separate export.
