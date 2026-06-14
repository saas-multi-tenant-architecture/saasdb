# @smta/better-auth

better-auth adapter for SMTA — wires better-auth's session identity into SMTA's PostgreSQL RLS enforcement, and exposes SMTA's tenant management functions as `auth.api.smta*` endpoints.

## What this does

- **Auth wiring:** Implements `core.get_current_user_id()` to read from `app.current_user_id` — the same session variable set by `withSMTA()` on each request. SMTA's RLS policies use this to filter rows.
- **User sync:** A trigger on better-auth's `user` table auto-creates `core.users_meta` rows on signup.
- **Plugin:** Adds `auth.api.smtaCreateOrganization()`, `auth.api.smtaListOrganizations()`, and other tenant management endpoints to the better-auth client. Adds `activeOrgId` to the session.
- **`withSMTA()`:** Transaction wrapper for Next.js Route Handlers and Server Actions.

## Prerequisites

1. Better-auth configured with UUID generation:

```typescript
export const auth = betterAuth({
  generateId: () => crypto.randomUUID(), // required — SMTA uses UUID primary keys
  plugins: [smtaPlugin({ pool })],
});
```

2. Run better-auth's migration **before** applying the SMTA SQL (the new-user trigger targets better-auth's `user` table):

```bash
# 1. Run better-auth migration (creates user, session, account, verification tables)
npx better-auth migrate

# 2. Apply SMTA better-auth adapter
psql $DATABASE_URL -f output/SMTA-better-auth-<timestamp>.sql
```

## Deployment

```bash
# Generate combined SQL deployment script
npm run build:better-auth
# → output/SMTA-better-auth-<timestamp>.sql
```

The output script contains `@smta/core` (all 58 files) followed by the 2 better-auth adapter files.

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
  generateId: () => crypto.randomUUID(),
  plugins: [smtaPlugin({ pool })],
});
```

### Next.js `proxy.ts` (auth protection)

Use better-auth's standard Next.js proxy pattern. See better-auth docs for the current `proxy.ts` API (replaced deprecated `middleware.ts` in Next.js post-2025).

## Running the adapter tests

The pgTap test file requires a database with the better-auth adapter deployed (not the Supabase adapter):

```bash
pg_prove -v "postgresql://<user>:<password>@<host>:<port>/<db>" \
  tests/adapters/01_better_auth_adapter.sql
```

The test file also requires the standard SMTA fixture data (test users, Bella Italia org). Load fixtures first:

```bash
psql $DATABASE_URL -f tests/fixtures/00_test_helpers.sql
psql $DATABASE_URL -f tests/fixtures/01_roles.sql
psql $DATABASE_URL -f tests/fixtures/02_test_users.sql
psql $DATABASE_URL -f tests/fixtures/03_bella_italia.sql
```

## Better-auth version compatibility

This package was designed for better-auth v1.x. Verify the `createAuthEndpoint` import path and session middleware access in `src/plugin/index.ts` against your installed version:

```bash
cat node_modules/better-auth/package.json | grep '"version"'
```

## User table name

By default targets better-auth's `"user"` table in the `public` schema. If you configure a table prefix (e.g. `tablePrefix: 'ba_'`), update the trigger target in `sql/init/new_user_trigger.sql` from `"user"` to `"ba_user"` and regenerate the deployment script.

## Supabase adapter migration note

If migrating from the `@smta/supabase` adapter, the `new_user_trigger.sql` file conditionally removes the `fk_users_meta_auth_users` foreign key constraint (which linked `core.users_meta` to Supabase's `auth.users` table). This removal is safe and idempotent — it only runs if the constraint exists.
