# SaaS Multi-Tenant Architecture - SMTA

## Introduction

*SaaS Multi-Tenant Architecture*, aka **SMTA**, is an open-source project designed to quickly bootstrap your SaaS and rapidly create a structurally sound and secure multi-tenant database, integrated with tools used in many SaaS applications today.

The architecture is designed to be modular, scalable, and extensible to customize it to your needs, combine with backend solutions like [Supabase](https://supabase.com/) or [PayloadCMS](https://payloadcms.com/), and reduce the complexity of multi-tenancy so that you can focus on building your MVP.

**SMTA** offers a layered approach to tenant isolation that reduces the risk of data leakage at the database level, leaving you free to develop your application knowing that the question of "Are you allowed to be here?" is already answered.

The core of **SMTA** is a series of PostgreSQL database scripts that create the structure which sits between the application and platform layers of your SaaS. There are no dependencies or complex extensions — it is all *plain old school SQL* (the 50+ year old technology that just works).

The following table diagram illustrates the layered design:

| Layer | Description |
|--|--|
| Application Layer | Your domain tables (`app` schema): projects, posts, documents, etc. → Accessed via DAL (CASL, Drizzle, Payload collections, Supabase client) |
| **SMTA Layer** | Tenant infrastructure: orgs, units, memberships, roles, audit, billing, and SaaS-management → Accessed via `public.*` SQL functions |
| Platform Layer | Authentication adapter: Supabase, PayloadCMS, or better-auth |

### Membership Has Its Privileges

In short, **SMTA** asks your authenticated users: "Are you a member of this tenant/organization/unit?" — a yes/no gate on row visibility that is plain and simple. Then within that answer, your application (using CASL) can ask, "Given that you have access, what are you allowed to do?" — action authorization based on the user's role.

### Extensible Connections

To further help speed development, **SMTA** offers extensible connections to common platforms. **SMTA** does NOT provide authentication or application-related services — it delegates those to an adapter.

- **Supabase** — The `@smta/supabase` adapter wires SMTA's auth interface to Supabase's JWT claims and Vault secrets, and exposes `public.*` functions via PostgREST. SMTA amplifies what Supabase already does well.
- **PayloadCMS** — The `@smta/payload` adapter wires SMTA's auth interface to Payload's session context via a PostgreSQL session variable, allowing SMTA to run alongside Payload's CMS without interfering with it.
- **better-auth** — The `@smta/better-auth` adapter wires SMTA's auth interface to better-auth's session context and adds SMTA tenant management as `auth.api.smta*` plugin endpoints. Includes a new-user trigger that auto-creates SMTA user records on signup.
- **Billing** — The `@smta/billing` TypeScript package provides a `BillingProvider` interface with implementations for [Stripe](https://stripe.com/) and [Lemon Squeezy](https://www.lemonsqueezy.com/).


## Goals

- Multi-tenant architecture within a single, shared PostgreSQL database
- PostgreSQL RLS (Row-Level Security) for tenant isolation
- Soft deletion, auditing, and payment processor billing integration
- Clear schema boundaries via SQL functions
- Adapter-agnostic core — same full feature set under Supabase, PayloadCMS, or better-auth


## Features

- Tenant isolation via PostgreSQL RLS
- Integration of database roles with access control library [CASL](https://casl.js.org/)
- Soft deletion to prevent data loss and enable recovery
- No-code auditing to track changes and actions at the database level
- Payment processor integration for billing (Stripe or Lemon Squeezy)
- Segmented and isolated SaaS management tables
- SQL functions enhanced with schema boundaries


## Schemas

These are the schemas used to segment functionality and enforce security boundaries. Removing direct table access from the `public` schema is an additional security measure to help prevent accidental exposure of sensitive data — all SMTA activity is routed through fully tested, secure SQL functions.

- `core` — identity, access, memberships, roles, audit logs, helper functions
- `platform` — SaaS-wide management, logs, billing, and overrides (service role only)
- `utils` — utility functions shared across all schemas
- `public` — SQL functions callable by clients (RPC only, no direct table access)
- `app` — all tenant-specific application logic (customized per SaaS application)


## Project Structure

SMTA is organized as a pnpm monorepo. Each package has its own `sql-scripts.json` defining the execution order of its SQL files.

```
packages/
├── core/          @smta/core          — adapter-agnostic SMTA schema (SQL)
├── supabase/      @smta/supabase      — Supabase auth/secrets adapter (SQL)
├── payload/       @smta/payload       — PayloadCMS auth adapter (SQL + TypeScript)
├── better-auth/   @smta/better-auth   — better-auth adapter + plugin (SQL + TypeScript)
├── billing/       @smta/billing       — BillingProvider interface + Stripe + Lemon Squeezy (TypeScript)
└── schemas/       @smta/schemas       — Zod v4 schemas for public.* RPC contracts (TypeScript)

scripts/
├── combine_files.js   — assembles a combined SQL deployment script from packages
├── run_tests.sh       — runs the full pgTap test suite
└── clean-up-database.sql
```

### Package boundaries

| Package | Contains |
|---|---|
| `@smta/core` | Core + platform schema, billing tables, RLS, public functions, triggers (56 SQL files) |
| `@smta/supabase` | JWT auth impl, Vault secrets impl, `auth.users` FK constraints (3 SQL files) |
| `@smta/payload` | Session-variable auth impl (1 SQL file) + TypeScript middleware |
| `@smta/better-auth` | Session-variable auth impl + new-user trigger (2 SQL files) + better-auth plugin |
| `@smta/billing` | `BillingProvider` interface, `StripeProvider`, `LemonSqueezyProvider` |
| `@smta/schemas` | Zod v4 schemas for all `public.*` RPC function inputs/outputs |


## Deployment

Generate a combined SQL deployment script for your chosen adapter:

```bash
# Supabase deployment (59 files)
npx @smta/cli --adapter supabase   # → SMTA-supabase-<timestamp>.sql

# Payload deployment (57 files)
npx @smta/cli --adapter payload    # → SMTA-payload-<timestamp>.sql

# better-auth deployment (60 files)
npx @smta/cli --adapter better-auth  # → SMTA-better-auth-<timestamp>.sql
```

All outputs deploy the full SMTA feature set. The only difference is the auth implementation and, for Supabase, the restoration of `auth.users` foreign keys.

Apply the generated script to your PostgreSQL database, then add your `app` schema tables on top.


## Testing

SMTA uses [pgTap](https://pgtap.org/) for database-level testing (41 test files, 506 tests).

```bash
npm test
```

See `TESTING.md` for setup instructions and `AGENTS.md` for contribution guidelines.


## Disclaimer
**USE SMTA AT YOUR OWN RISK!** The author is not responsible for any data loss or other issues that may arise from using this project.

This project is not affiliated with Supabase, PayloadCMS, Stripe, or Lemon Squeezy in any way. 

## Origin

**SMTA** is a *labor of love*. It was born out of the frustration of having a great SaaS idea, but always stumbling over the same issue: building a structurally sound multi-tenant database. In many fledgling projects, building the elements of SMTA is put aside in the interest of expediency, but this creates substantial technical debt. As an application grows, establishing a robust multi-tenant architecture can involve awkward workarounds, inefficient RLS policies that do not scale, or annoying inconveniences for end-users. In some cases, multi-tenancy is achieved using a "one-database-per-tenant" model, which can be more costly or lack cross-tenant integration (such as macro-analytics).

**SMTA** originated to help solve the problem of building a multi-tenant application from the ground up. A great SaaS idea shouldn't have to begin with the rudimentary tenant isolation question, which is something most SaaS applications need. Rather, focus on the problem you are trying to solve.

*Labor of Love: Thousands of AI tokens were used to build this project so you don't have to!*