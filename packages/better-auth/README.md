# @smta/better-auth

better-auth adapter for SMTA — wires better-auth's session identity into SMTA's PostgreSQL RLS enforcement, and exposes SMTA's tenant management functions as `auth.api.smta*` endpoints.

## What this does

- **Auth wiring:** Implements `core.get_current_user_id()` to read from `app.current_user_id` — the same session variable set by `withSMTA()` on each request. SMTA's RLS policies use this to filter rows.
- **User sync:** A trigger on better-auth's `user` table auto-creates `core.users_meta` rows on signup.
- **Plugin:** Adds `auth.api.smtaCreateOrganization()`, `auth.api.smtaListOrganizations()`, and other tenant management endpoints to the better-auth client. Adds `activeOrgId` to the session.
- **`withSMTA()`:** Transaction wrapper for Next.js Route Handlers and Server Actions.

## Role model

SMTA core defines two adapter-agnostic PostgreSQL roles:

| Role | Attributes | Purpose |
|------|-----------|---------|
| `app_user` | `NOLOGIN`, **NOT** `BYPASSRLS` | Runtime identity — RLS is enforced against it |
| `app_admin` | `NOLOGIN`, `BYPASSRLS` | Migrations, seed, admin DML — bypasses RLS |

RLS enforcement does **not** depend on which role is connected. It depends on `core.get_current_user_id()` reading the `app.current_user_id` GUC set by `withSMTA()` on each request. This means: **the application backend must connect as a login role that inherits `app_user` (NOT BYPASSRLS)**. If the connected role has `BYPASSRLS`, all RLS policies are skipped and tenants can read each other's data.

Migrations should connect as a login role that inherits `app_admin`.

`roles.sql` provides a deploy-time hook: set the `smta.app_login_role` and `smta.admin_login_role` GUCs before applying the deployment script and the grants are wired automatically. If you omit these GUCs, run the grants manually after deploy:

```sql
GRANT app_user  TO your_app_role;
GRANT app_admin TO your_migration_role;
```

## Prerequisites

1. Choose an id mode (see [Better-Auth id modes](#better-auth-id-modes) below) and pass `--better-auth-ids` when deploying.

2. Run better-auth's migration **before** applying the SMTA SQL (the new-user trigger targets better-auth's `user` table):

```bash
# 1. Run better-auth migration (creates user, session, account, verification tables)
npx better-auth migrate

# 2. Apply SMTA better-auth adapter
psql $DATABASE_URL -f output/SMTA-better-auth-<timestamp>.sql
```

## Deployment

```bash
npx @smta/cli --adapter better-auth --better-auth-ids <uuid|mapped>
# → SMTA-better-auth-<timestamp>.sql  (60 SQL files combined)
```

`--better-auth-ids` is **required** when `--adapter better-auth`. See the next section for which mode to choose.

The output script contains `@smta/core` (58 files) followed by the better-auth adapter files (roles, secrets, the chosen auth impl, and the matching signup trigger).

## Better-Auth id modes

SMTA's RLS layer uses UUID primary keys. The `--better-auth-ids` flag selects how better-auth user ids are mapped to those UUIDs.

### `uuid` (recommended)

better-auth is configured to emit UUIDs as user ids. `core.get_current_user_id()` casts `app.current_user_id` directly to `UUID` — no mapping table, no extra query per request.

To enable this, configure better-auth's `advanced.database.generateId`:

```typescript
export const auth = betterAuth({
  advanced: {
    database: {
      generateId: () => crypto.randomUUID(),
    },
  },
  plugins: [smtaPlugin({ pool })],
});
```

### `mapped`

better-auth ids are arbitrary strings. SMTA mints its own UUID per user and resolves `external_id` → `user_id` via `core.user_identities` on each call. This mode requires **zero changes** to your better-auth configuration.

The trade-off: each call to `core.get_current_user_id()` joins `core.user_identities` on `external_id`.

## Secrets

The better-auth adapter uses pgcrypto (`pgp_sym_encrypt`) to store secrets in `core.encrypted_secrets`. The symmetric key is **never hard-coded** — it is read from the `app.secrets_key` GUC.

**The backend must set `app.secrets_key` on each session or connection before any secret store/read operation:**

```sql
SET app.secrets_key = 'your-encryption-key';
```

If `app.secrets_key` is not set, `core.store_secret_impl()` and `core.read_secret_impl()` raise an exception.

## Usage

### `withSMTA()` in a Route Handler

```typescript
import { auth } from '@/lib/auth';
import { withSMTA } from '@smta/better-auth';
import { pool } from '@/lib/db';

export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });

  return withSMTA(pool, session?.user?.id, async (client) => {
    const { rows } = await client.query(
      'SELECT * FROM public.list_my_organizations()'
    );
    return Response.json(rows);
  });
}
```

### Plugin registration

```typescript
import { betterAuth } from 'better-auth';
import { smtaPlugin } from '@smta/better-auth';
import { pool } from '@/lib/db';

export const auth = betterAuth({
  advanced: {
    database: {
      generateId: () => crypto.randomUUID(), // only for uuid mode
    },
  },
  plugins: [smtaPlugin({ pool })],
});
```

### Next.js `proxy.ts` (auth protection)

Use better-auth's standard Next.js proxy pattern. See better-auth docs for the current `proxy.ts` API (replaced deprecated `middleware.ts` in Next.js post-2025).

## Running the adapter tests

The adapter test file (`tests/adapters/01_better_auth_adapter.sql`) is included in the main test suite and runs automatically with the fixture data already loaded:

```bash
pnpm test
```

This runs all 506 tests across 41 files, including the 8 adapter-specific tests.

**Standalone** (for debugging against a specific database — requires fixtures loaded first):

```bash
psql $DATABASE_URL -f tests/fixtures/00_test_helpers.sql
psql $DATABASE_URL -f tests/fixtures/01_roles.sql
psql $DATABASE_URL -f tests/fixtures/02_test_users.sql
psql $DATABASE_URL -f tests/fixtures/03_bella_italia.sql

docker exec -i supabase-db psql -U supabase_admin -d postgres \
  < tests/adapters/01_better_auth_adapter.sql
```

## Better-auth version compatibility

This package was designed for better-auth v1.x. Verify the `createAuthEndpoint` import path and session middleware access in `src/plugin/index.ts` against your installed version:

```bash
cat node_modules/better-auth/package.json | grep '"version"'
```

## User table name

By default targets better-auth's `"user"` table in the `public` schema. If you configure a table prefix (e.g. `tablePrefix: 'ba_'`), update the trigger target in the relevant `new_user_trigger_*.sql` from `"user"` to `"ba_user"` and regenerate the deployment script.

## Supabase adapter migration note

Both signup-trigger variants (`new_user_trigger_uuid.sql` and `new_user_trigger_mapped.sql`) conditionally drop the `fk_users_meta_auth_users` foreign key constraint on `core.users_meta` before installing the new trigger. This removal is safe and idempotent — it only executes if the constraint exists (i.e. when migrating from the `@smta/supabase` adapter).
