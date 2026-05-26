# @smta/core

**[Documentation](https://smta.dev)** · **[GitHub](https://github.com/saas-multi-tenant-architecture/saasdb)**

The adapter-agnostic PostgreSQL schema for [SMTA (SaaS Multi-Tenant Architecture)](https://smta.dev) — tenant isolation, RLS policies, audit logging, billing tables, and the full `public.*` RPC surface.

## What's in this package

56 SQL files covering the entire SMTA core schema:

| Area | What it creates |
|------|-----------------|
| Schemas | `core`, `platform`, `utils`, `public`, `app` |
| Tables | Organizations, units, memberships, roles, invitations, audit logs, billing customers and subscriptions |
| RLS policies | Row-level tenant isolation on all core and platform tables |
| Triggers | Auto-provisioning on new user and organization creation |
| Public functions | The full `public.*` RPC interface callable by application code |
| Platform functions | Service-role management functions for SaaS operators |

## Usage

This package is consumed by [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) — you do not install it directly. To deploy SMTA to your database, run:

```bash
npx @smta/cli --adapter supabase
# or
npx @smta/cli --adapter payload
```

The CLI resolves `@smta/core` and your chosen adapter, combines their SQL files in execution order, and writes a single deployment script to your current directory.

See the [Installation guide](https://smta.dev/getting-started/installation/) for full instructions.

## Part of the SMTA package family

| Package | Purpose |
|---------|---------|
| **`@smta/core`** | This package — adapter-agnostic SQL schema |
| [`@smta/supabase`](https://www.npmjs.com/package/@smta/supabase) | Supabase auth and Vault adapter SQL |
| [`@smta/payload`](https://www.npmjs.com/package/@smta/payload) | Payload CMS adapter SQL + middleware |
| [`@smta/billing`](https://www.npmjs.com/package/@smta/billing) | BillingProvider interface (Stripe, Lemon Squeezy) |
| [`@smta/schemas`](https://www.npmjs.com/package/@smta/schemas) | Zod v4 schemas for all `public.*` RPC contracts |
| [`@smta/cli`](https://www.npmjs.com/package/@smta/cli) | Deployment CLI |

## License

MIT
