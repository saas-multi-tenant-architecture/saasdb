# @smta/supabase

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

The Supabase adapter for [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev). Maps Supabase's GoTrue roles onto SMTA core's adapter-agnostic role model, wires the auth and secrets interfaces to Supabase's JWT claims and Vault, and restores `auth.users` foreign key constraints to the core tables.

## What this does

`@smta/core` is adapter-agnostic — it owns two neutral roles (`app_user`, `app_admin`) but does not bind them to any auth system. This adapter supplies the Supabase-specific add-backs:

| File | Purpose |
|------|---------|
| `grants_role_mapping.sql` | Maps `authenticated` → `app_user` and `service_role` → `app_admin` |
| `auth_supabase_impl.sql` | Implements `core.get_current_user_id()` using `auth.uid()` from the Supabase JWT |
| `secrets_supabase_impl.sql` | Implements `core.store_secret_impl()`, `core.read_secret_impl()`, and `core.delete_secret_impl()` using Supabase Vault |
| `constraints.sql` | Restores `auth.users` foreign keys on `core.users_meta`, `core.memberships`, `core.unit_memberships`, `core.invitations`, `platform.platform_users`, and `platform.tenant_secrets` |
| `new_user_trigger.sql` | Binds `core.handle_new_user()` to `auth.users` (core defines the function but does not attach it) |
| `disable_graphql.sql` | Drops the `pg_graphql` extension (Supabase enables it by default; SMTA does not use it) |

**Behavior is unchanged from before** — the Supabase adapter continues to work identically. The only change is that the responsibilities above have been explicitly separated from core so that non-Supabase adapters (Payload, better-auth) can use core without Supabase dependencies.

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
