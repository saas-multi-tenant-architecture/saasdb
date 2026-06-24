# SMTA `@smta/better-auth` adapter — load-blocking Supabase residue

**Generated file reviewed:** `SMTA-better-auth-1782169582820.sql` (SMTA 0.6.0, 5590 lines)
**Date:** 2026-06-24
**Verified against:** local Postgres 18 + pgTAP (`docker/compose.local.yml`), empirical test-load into a throwaway database.

This document lists issues to fix **in the SMTA CLI's `@smta/better-auth` adapter**, then regenerate.
Nothing in the HelmetFires repo was edited. The generated SQL is the source of record.

---

## TL;DR

0.6.0 **correctly fixes the Better Auth tenant-context path** (see "What's already correct"), but the
adapter still emits the **Supabase platform-admin layer verbatim**. The file does **not** load on a
plain (non-Supabase) Postgres because it depends on Supabase-provided objects that no longer exist:
`authenticated`/`anon` roles, the `auth` schema, `auth.users`, and `auth.uid()`.

**Empirical confirmation:** after stubbing only those Supabase prerequisites (create roles
`authenticated`/`anon`/`service_role`; create a throwaway `auth.users`; create `auth.uid()`), the
**entire file loads with zero errors** and produces all expected objects (11 `core` tables, 29 `core`
functions, 12 `platform` tables). So the file is structurally sound — the problem is undeclared
Supabase prerequisites, all confined to the `platform.*` admin layer plus a leftover dead trigger.

---

## What's already correct (0.6.0 fixed the real blocker)

These are right and should be preserved:

- **`core.get_current_user_id()` override** (line ~5522) reads the txn-local Better Auth variable:
  ```sql
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
  ```
  This is exactly the path the HelmetFires design + SMTA integration contract require.
- **Gate helpers** `core.is_org_member(p_org_id uuid)` and `core.is_unit_member(p_unit_id uuid)` exist
  with the expected names/signatures.
- **`core.users_meta → auth.users` FK is dropped** by the tail remediation (lines ~5545-5554).
- **New-user trigger** on Better Auth's `public."user"` table is added (lines ~5559-5590).

---

## Issues to fix (in order encountered at load)

### 1. Missing roles `authenticated` / `anon` — **hard load blocker** (first failure)
- **Where:** lines 27-29 (`GRANT USAGE ON SCHEMA … TO authenticated`), 36-38 (`ALTER DEFAULT
  PRIVILEGES … TO authenticated`), 42-43 (`REVOKE … FROM authenticated, anon, public`), plus all
  table-level `GRANT … TO authenticated` (e.g. lines 820-844) and the `ALTER DEFAULT PRIVILEGES`.
- **Error:** `ERROR: role "authenticated" does not exist` (stops the load immediately).
- **Root cause:** Supabase ships the `authenticated`/`anon`/`service_role` roles; Better Auth / plain
  Postgres does not.
- **Fix (pick one in the adapter):**
  - (a) Emit `DO $$ … CREATE ROLE authenticated / anon …$$;` guards at the top of the better-auth
    output (idempotent, `IF NOT EXISTS`), **or**
  - (b) Replace the Supabase role model with whatever role the better-auth deployment actually uses
    (and drop the Supabase-specific `anon`/grants that have no meaning here).

### 2. `platform.platform_users.supabase_user_id` FK to `auth.users` — **hard load blocker**
- **Where:** line 175 — `supabase_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
- **Root cause:** Supabase GoTrue table. In Better Auth the user table is `public."user"`; no `auth`
  schema/`auth.users` is created anywhere in the file.
- **Fix:** the better-auth adapter should rewrite this FK to the Better Auth user table
  (`public."user"(id)`) or omit it / make the column unconstrained — consistent with how the tail
  already drops the analogous `core.users_meta` FK. Rename `supabase_user_id` accordingly.

### 3. `platform.tenant_secrets.user_id` FK to `auth.users` — **hard load blocker**
- **Where:** line 1066 — `user_id UUID REFERENCES auth.users(id)` (inside the Supabase Vault secrets table)
- **Root cause:** same as #2; this whole table is built around Supabase Vault (`vault_key_id`,
  `core.store_secret_impl` / `delete_secret_impl` stubs that "raise unless an adapter overrides").
- **Fix:** rewrite/omit the `auth.users` FK; and decide whether the Supabase-Vault secrets feature
  should even ship in a better-auth deployment (the `store_secret_impl`/`delete_secret_impl` stubs at
  lines ~69/77 will raise at runtime unless the better-auth adapter provides a non-Vault implementation).

### 4. Dead Supabase new-user trigger on `auth.users` — **hard load blocker + redundant**
- **Where:** `core.handle_new_user()` (line ~856) and `DROP TRIGGER … ON auth.users` / `CREATE TRIGGER
  trg_on_auth_user_created AFTER INSERT ON auth.users` (lines 872-875).
- **Root cause:** this is the Supabase signup trigger. It is **already superseded** by the better-auth
  trigger emitted in the tail (`core.handle_new_better_auth_user` + `trg_on_better_auth_user_created`
  on `public."user"`, lines ~5559-5590).
- **Fix:** the better-auth adapter should **not emit** the `auth.users` trigger (and likely not
  `core.handle_new_user()` either) — it's both a load blocker and duplicate behavior.

### 5. `auth.uid()` in function bodies — **not load-blocking, but runtime-broken**
- **Where (all in `platform.*` admin functions HelmetFires does not call):**
  `platform.is_platform_user` (~1738), `platform.is_platform_super_admin` (~1753),
  `platform.create_platform_user` (~4535/4578), `platform.update_platform_user` (~4613),
  `platform.delete_platform_user` (~4680), `platform.log_platform_action` (~4494),
  `platform.create_platform_feature_flag` (~4824), `platform.update_feature_flag` (~4912),
  `platform.delete_feature_flag` (~4942), `platform.get_platform_user_role` (~5012),
  `platform.set_setting` (~5113), `platform.delete_setting` (~5154),
  `platform.add_subscription_product` (~5324).
  Also `public.invite_user_to_organization` (~3037) reads `FROM auth.users WHERE email = …` (~3043).
- **Root cause:** `auth.uid()` is Supabase GoTrue. plpgsql bodies aren't resolved at load, so these
  don't block the load, but they will fail at call time once reached.
- **Fix:** the better-auth adapter should rewrite `auth.uid()` → `core.get_current_user_id()` (or its
  equivalent) throughout. For `public.invite_user_to_organization`, the lookup should come from
  `core.users_meta` (the file's own comments elsewhere note `auth.users` is intentionally not
  accessible to the app role).

### 6. Supabase Vault secrets stubs — **runtime-broken if used**
- **Where:** `core.store_secret_impl` (~69), `core.delete_secret_impl` (~74-77) raise
  `'… not implemented. Deploy an adapter.'`; consumed by `create_secret`/`list_secrets` (~2008+).
- **Fix:** if the secrets feature is in scope for better-auth, provide a non-Vault implementation;
  otherwise omit the feature so the stubs don't ship.

### 7. Cosmetic / naming residue (non-blocking, nice to clean up)
- Stub message at line 55 still reads `'… Deploy an adapter (supabase or payload).'` — should mention
  better-auth.
- Comments throughout reference "Supabase auth", "Supabase Storage", "Supabase Vault",
  `actor_id -- auth.uid()`, etc.
- `platform.platform_users.supabase_user_id` column name (see #2).

---

## Suggested fix summary for the adapter

| # | Object | Action |
|---|--------|--------|
| 1 | `authenticated`/`anon` role grants | create the roles (idempotent) or drop the Supabase role model |
| 2 | `platform.platform_users` FK | rewrite `auth.users(id)` → `public."user"(id)` or drop |
| 3 | `platform.tenant_secrets` FK + Vault | rewrite/drop FK; decide if Vault secrets ship under better-auth |
| 4 | `core.handle_new_user` + `auth.users` trigger | do not emit (superseded by better-auth trigger) |
| 5 | `auth.uid()` in `platform.*` + `invite_user_to_organization` | rewrite to `core.get_current_user_id()` / `core.users_meta` |
| 6 | `store_secret_impl`/`delete_secret_impl` stubs | implement for better-auth or omit |
| 7 | comments / stub text / column names | rename away from "supabase" |

All hard load blockers are #1-#4. After those four, the file loads clean; #5-#6 are runtime
correctness for the `platform.*` admin layer (which HelmetFires does not currently use), and #7 is
cosmetic.

## How this was verified
1. `psql -v ON_ERROR_STOP=1 < SMTA-better-auth-1782169582820.sql` on a fresh DB → first error
   `role "authenticated" does not exist`.
2. Stubbed only: `CREATE ROLE authenticated/anon/service_role`, `CREATE SCHEMA auth`,
   `CREATE TABLE auth.users(id uuid primary key, email text)`, `CREATE FUNCTION auth.uid()`.
3. Re-ran the full file → **0 errors**; confirmed 11 `core` tables, 29 `core` functions, 12 `platform`
   tables, and that `core.get_current_user_id()` / `core.is_org_member` / `core.is_unit_member` are
   present and correct.
