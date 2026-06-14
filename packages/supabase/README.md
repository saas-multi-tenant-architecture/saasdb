# @smta/supabase

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

The Supabase adapter for [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev). Wires SMTA's auth and secrets interfaces to Supabase's JWT claims (`auth.uid()`) and Vault, and adds `auth.users` foreign key constraints to the core tables.

## What's in this package

3 SQL files that supplement `@smta/core` for Supabase deployments:

| File | Purpose |
|------|---------|
| `auth_supabase_impl.sql` | Implements `core.get_current_user_id()` using `auth.uid()` from the Supabase JWT |
| `secrets_supabase_impl.sql` | Implements `core.store_secret_impl()` and `core.delete_secret_impl()` using Supabase Vault |
| `constraints.sql` | Adds foreign keys from SMTA tables to `auth.users` |

## Usage

This package is consumed by [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) — you do not install it directly. To deploy SMTA with the Supabase adapter, run:

```bash
npx @smta/cli --adapter supabase
```

The CLI combines `@smta/core` and `@smta/supabase` into a single deployment script. Paste the output into the Supabase SQL Editor or apply via `psql`.

See the [Supabase Quick Start](https://smta.dev/getting-started/quickstart-supabase/) for the full walkthrough.

## Part of the SMTA package family

| Package | Purpose |
|---------|---------|
| [`@smta/core`](https://www.npmjs.com/package/@smta/core) | Adapter-agnostic SQL schema |
| **`@smta/supabase`** | This package — Supabase adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/better-auth`](https://www.npmjs.com/package/@smta/better-auth) | better-auth adapter SQL + plugin |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |

## License

MIT
