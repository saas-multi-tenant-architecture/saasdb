# @smta/payload

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

The Payload CMS adapter for [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev). Provides the SQL auth implementation for Payload deployments and a TypeScript middleware to inject the current user's ID into the PostgreSQL session before each request.

## What's in this package

**SQL** (deployed via `@smta/cli`):

| File | Purpose |
|------|---------|
| `roles.sql` | Deploy-time hook to wire login roles into `app_user` / `app_admin` |
| `auth_payload_impl.sql` | Implements `core.get_current_user_id()` using the `app.current_user_id` PostgreSQL session variable |
| `secrets_pgcrypto_impl.sql` | Implements `core.store_secret_impl()` / `core.read_secret_impl()` using pgcrypto |

**TypeScript middleware**:

- `injectUserContext(db, userId)` — sets `app.current_user_id` for the current transaction
- `clearUserContext(db)` — clears the session variable

## Role model

SMTA core defines two adapter-agnostic PostgreSQL roles:

| Role | Attributes | Purpose |
|------|-----------|---------|
| `app_user` | `NOLOGIN`, **NOT** `BYPASSRLS` | Runtime identity — RLS is enforced against it |
| `app_admin` | `NOLOGIN`, `BYPASSRLS` | Migrations, seed, admin DML — bypasses RLS |

RLS enforcement does **not** depend on which role is connected. It depends on `core.get_current_user_id()` reading the `app.current_user_id` GUC set by `injectUserContext()` on each request. This means: **Payload's database connection role must inherit `app_user` (NOT BYPASSRLS)**. If the connected role has `BYPASSRLS`, all RLS policies are skipped and tenants can read each other's data.

The role used for running migrations should inherit `app_admin`.

`roles.sql` provides a deploy-time hook: set the `smta.app_login_role` and `smta.admin_login_role` GUCs before applying the deployment script and the grants are wired automatically. If you omit these GUCs, run the grants manually after deploy:

```sql
GRANT app_user  TO your_payload_db_role;
GRANT app_admin TO your_migration_role;
```

## Secrets

The Payload adapter uses pgcrypto (`pgp_sym_encrypt`) to store secrets in `core.encrypted_secrets`. The symmetric key is **never hard-coded** — it is read from the `app.secrets_key` GUC.

**The backend must set `app.secrets_key` on each session or connection before any secret store/read operation:**

```sql
SET app.secrets_key = 'your-encryption-key';
```

If `app.secrets_key` is not set, `core.store_secret_impl()` and `core.read_secret_impl()` raise an exception.

## Deploy the SQL

```bash
npx @smta/cli --adapter payload
```

Apply the generated script to your Payload project's PostgreSQL database. See the [Payload Quick Start](https://smta.dev/getting-started/quickstart-payload/) for full instructions.

## Install the TypeScript middleware

```bash
npm install @smta/payload
```

## Usage

Call `injectUserContext` inside a Payload `beforeOperation` hook so SMTA's RLS policies can identify the current user on every query:

```typescript
import { injectUserContext } from '@smta/payload'

// In your Payload collection's hooks
const MyCollection: CollectionConfig = {
  slug: 'my-collection',
  hooks: {
    beforeOperation: [
      async ({ req }) => {
        if (req.user?.id) {
          await injectUserContext(req.payload.db.drizzle, req.user.id)
        }
      },
    ],
  },
}
```

`injectUserContext` uses `SET LOCAL` so the session variable is scoped to the current transaction — it is automatically cleared when the transaction ends.

For more on how SMTA's RLS policies use this value, see the [Adapter Pattern docs](https://smta.dev/architecture/adapter-pattern/).

## Part of the SMTA package family

| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase adapter SQL |
| **`@smta/payload`** | This package — Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |

## License

MIT
