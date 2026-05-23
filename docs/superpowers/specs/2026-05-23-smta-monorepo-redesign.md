# SMTA Monorepo Redesign Spec
*Date: 2026-05-23*

## Problem

SMTA (SaaS Multi-Tenant Architecture) is a PostgreSQL-native multi-tenancy framework originally
built to augment Supabase. It is incomplete and has three specific organizational problems:

1. **Zod schemas model raw tables** instead of `public.*` RPC function contracts (inputs/outputs)
2. **Auth/RLS is Supabase-coupled** via `auth.uid()` and `vault.secrets`
3. **Billing integration is placeholder-grade** — no real provider abstraction

Goal: Restructure as a monorepo so the framework works with either Supabase or Payload CMS as the
underlying platform, and can be formally published as npm packages.

---

## Authorization Architecture

Two layers answer **different, non-overlapping questions**:

**RLS (database layer):** "Are you a member of this tenant/org/unit?"
- A row-visibility membership gate — nothing more
- Implemented via: `is_org_member()`, `is_super_admin()`, `is_unit_member()`, etc.
- Never enforces what actions a member can perform

**CASL (application layer):** "Given access, what are you allowed to do?"
- Action authorization, built from SMTA role data at login
- CASL reads `list_my_memberships()` output to build `AbilityBuilder`
- CASL is a read-only consumer of SMTA's role model

These layers are orthogonal. Drift is not a risk. This comment block belongs at the top of
`packages/core/sql/rls/policies.sql` as mandatory reading before modifying any policy.

---

## Target Structure

```
smta/
├── pnpm-workspace.yaml
├── turbo.json
├── packages/
│   ├── core/      # Pure PostgreSQL: tables, triggers, RBAC, audit, RLS (no auth.uid() assumptions)
│   ├── supabase/  # Supabase adapter: auth.uid(), Vault, PostgREST config, platform schema
│   ├── payload/   # Payload CMS adapter: session injection, media, custom endpoints
│   ├── billing/   # BillingProvider interface + Stripe + Lemon Squeezy implementations
│   └── schemas/   # Zod schemas for public.* function contracts (inputs + outputs only)
```

Package dependency graph (arrows = "depends on"):
- `supabase` → `core`
- `payload` → `core`
- `billing` → `supabase` or `payload` (accepts generic `Pool`)
- `schemas` → nothing (pure TypeScript)
- `core` → nothing

---

## Section 1: Auth Abstraction

### The Problem

`auth.uid()` appears in 7 RLS helper functions and throughout `_public/` functions.
Four core tables also have structural FKs to `auth.users(id)`:
- `core.memberships.user_id`
- `core.unit_memberships.user_id`
- `core.users_meta.id`
- `core.invitations.invited_by`, `accepted_by`

### Solution: Pluggable `core.get_current_user_id()`

**Core package** — stub that fails loudly without an adapter:
```sql
-- packages/core/sql/auth/interface.sql
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RAISE EXCEPTION 'core.get_current_user_id() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core;
```

**Supabase adapter:**
```sql
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, auth, public;
```

**Payload adapter:**
```sql
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

**Payload Node.js middleware** injects the session variable before each query:
```typescript
await db.query(`SET LOCAL app.current_user_id = '${userId}'`);
```

Every `auth.uid()` in `packages/core/` becomes `core.get_current_user_id()`.
Platform functions in `packages/supabase/` keep `auth.uid()` directly — they are intentionally
Supabase-specific.

### FK Decoupling

Remove `REFERENCES auth.users(id)` from core tables — `user_id UUID NOT NULL` without FK.
Supabase adapter adds them back:
```sql
-- packages/supabase/sql/constraints.sql
ALTER TABLE core.memberships
  ADD CONSTRAINT fk_memberships_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
-- repeat for unit_memberships, users_meta, invitations
```

The `new_user.sql` trigger (fires on `auth.users`) moves to the Supabase adapter.
The Payload adapter provides a `beforeOperation` hook that inserts into `core.users_meta` at user
creation.

### Test Helper Update

```sql
-- Set both so tests work regardless of which adapter is deployed
PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
PERFORM set_config('app.current_user_id', p_user_id::text, true);
```

---

## Section 2: RLS Reorganization

### Comment Block Required in policies.sql

```sql
-- ============================================================
-- RLS PHILOSOPHY — READ BEFORE MODIFYING
-- ============================================================
-- RLS answers ONE question: "Are you a member of the tenant
-- that owns this row?" It is a membership gate — nothing more.
--
-- Action authorization (what members can do) is CASL's job.
-- CASL reads SMTA role data to build abilities at the app layer.
--
-- Do NOT add role-based action checks to RLS policies.
-- That creates duplicate, conflicting authorization logic.
-- ============================================================
```

### Changes

- `auth.uid()` in `sql/_core/rls/helpers.sql` and `policies.sql` → `core.get_current_user_id()`
- `sql/_platform/rls/lockdown.sql` stays in the Supabase adapter (Supabase-specific)
- `sql/_core/rls/` → `packages/core/sql/rls/`

### Secrets Abstraction

Extract Vault calls from `sql/_core/functions/secrets.sql` into a provider stub:
- **Core**: declares `core.store_secret_impl()` stub
- **Supabase adapter**: implements via `vault.create_secret()`
- **Payload**: Bitwarden Secrets Manager via external Node.js API call; reference stored in DB.
  Rename `vault_key_id` column to `secret_ref` (provider-agnostic).

---

## Section 3: Schemas Package (`@smta/schemas`)

### Problem

Current schemas model raw table columns. They should model function contracts.

### Pattern

Each `public.*` RPC function gets a request schema and response schema:

```typescript
// packages/schemas/src/rpc/organizations.ts
// SYNC-CHECK: public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)

export const createOrganizationInputSchema = z.object({
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});
export const createOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  created_at: z.coerce.date(),
});
```

### Template

`schema_validation/_schemas/invitations.ts` is the model. It already has
`createInvitationInputSchema`, `invitationResponseSchema`, `acceptInvitationInputSchema`.
Remove the table-level `invitationsSchema` (lines 8–22). Only function-contract schemas remain.

### Sync Strategy

A pgTap test queries `information_schema.parameters` for each `public.*` function and asserts
expected parameter names/types. Fails if a SQL function signature changes without updating schemas.

### Zod Version

Pin to `"zod": "^4.0.0"` directly. Current code uses the v3→v4 shim (`from 'zod/v4'`).

---

## Section 4: Billing Package (`@smta/billing`)

### Database Changes

```sql
ALTER TABLE platform.billing_customers
  ADD COLUMN provider TEXT NOT NULL DEFAULT 'stripe'
    CHECK (provider IN ('stripe', 'lemon_squeezy'));
ALTER TABLE platform.billing_customers
  RENAME COLUMN paymentprocessor_customer_id TO provider_customer_id;
-- same for billing_subscriptions
```

SMTA core stores only references. No Stripe/Lemon Squeezy SDK dependency in core or adapters.

### TypeScript Provider Interface

```typescript
// packages/billing/src/provider.ts
export interface BillingProvider {
  readonly name: 'stripe' | 'lemon_squeezy';
  createCheckout(params: CheckoutParams): Promise<CheckoutResult>;
  handleWebhook(event: WebhookEvent): Promise<ParsedWebhookEvent>;
  getSubscription(providerSubscriptionId: string): Promise<SubscriptionResult>;
  cancelSubscription(providerSubscriptionId: string): Promise<void>;
  recordCustomer(organizationId: string, providerCustomerId: string, billingEmail: string): Promise<void>;
  recordSubscriptionUpdate(params: ParsedWebhookEvent): Promise<void>;
}
```

Reference implementations: `StripeProvider` and `LemonSqueezyProvider`. Both accept a generic
`Pool` (not a Supabase-specific client) so they work with either adapter.

---

## Section 5: Monorepo Tooling

- **pnpm workspaces** + **Turborepo** for build orchestration
- `combine_files.js` retained and made per-package; root build composes them in dependency order
- TypeScript project references for incremental builds
- Final deployment artifact: `core.sql + adapter.sql + billing.sql` concatenated

---

## Integration Pattern for New SaaS Projects

SMTA is **infrastructure**, not the whole application:

```
Application layer  →  _app/ domain tables (projects, posts, etc.)
                      DAL: Drizzle, Payload collections, or Supabase client
                      Types: from the DAL, not @smta/schemas

SMTA layer         →  Tenancy infrastructure (orgs, units, roles, audit, billing)
                      API: public.* SQL functions
                      Types: @smta/schemas

Platform layer     →  Auth + storage: Supabase or Payload CMS
```

RLS connects the layers. `_app/` tables get policies using `core.is_org_member()` — the RLS gate
enforces tenancy regardless of which DAL is used above it.

**SMTA does not prescribe a DAL for application tables.**

Integration sequence for a new SaaS:
1. Deploy SMTA (core + adapter)
2. Use `public.*` functions + `@smta/schemas` types for tenancy operations
3. Define `_app/` tables with `organization_id` + SMTA RLS policies
4. Use chosen DAL for domain data (types from Drizzle/Payload, not SMTA)
5. At login: `list_my_memberships()` → CASL `AbilityBuilder` → action authorization live

---

## Migration Phases

| Phase | What | Risk | Gate |
|-------|------|------|------|
| 0 | Fix 6 failing tests | Low | All 42 tests pass |
| 1 | Auth abstraction in-place (SQL only) | Medium | All tests pass |
| 2 | Monorepo directory structure (move files, no SQL changes) | Low | All tests pass |
| 3 | Secrets abstraction (Vault → provider stub) | Medium | Secrets tests pass |
| 4 | Remove `auth.users` FKs from core, add back in Supabase adapter | High | All tests pass |
| 5 | Schemas package (function-contract schemas replace table schemas) | Low | No pgTap impact |
| 6 | Billing package (interface + Stripe + Lemon Squeezy) | Medium | Billing tests pass |

Each phase is a separate deployment. Full test suite must pass before the next phase begins.

---

## Risks and Unknowns

1. **Payload `SET LOCAL` injection**: Must confirm `@payloadcms/db-postgres` exposes a per-query
   hook before implementing the Payload adapter. Fallback: `SET SESSION` via `pg-pool` connect event.

2. **`auth.users` FK removal**: No production data exists currently — migration risk is low.
   Document the constraint-removal pattern for future reference.

3. **Tests are Supabase-dependent**: After Phase 4, `packages/core/tests/` can target plain
   PostgreSQL. Existing `tests/` become the Supabase adapter integration suite.

4. **`supabase_user_id` column**: Rename to `auth_user_id` in `platform.platform_action_logs`
   during Phase 2.

---

## Critical Files

| File | Why Critical |
|------|-------------|
| `sql/_core/rls/helpers.sql` | 7 `auth.uid()` calls — first Phase 1 target |
| `sql/_core/functions/secrets.sql` | Vault coupling to extract in Phase 3 |
| `sql/_core/tables/memberships.sql` | `auth.users` FK to decouple in Phase 4 |
| `schema_validation/_schemas/invitations.ts` | Template for function-contract schema pattern |
| `sql-scripts.json` | Deployment manifest to split per-package in Phase 2 |
