# De-Supabase Core & Fix the Better-Auth Adapter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `@smta/core` load standalone on vanilla PostgreSQL so the better-auth (and payload) adapter output deploys cleanly, while keeping the Supabase adapter behavior-identical.

**Architecture:** Finish the adapter-agnostic refactor the codebase already started. Core creates two neutral roles (`app_user`, `app_admin`), uses `core.get_current_user_id()` everywhere (never `auth.uid()`), and contains no `auth.*` references. Each adapter package appends only its deltas: the Supabase adapter restores its role mappings + `auth.users` FKs + Vault secrets; better-auth/payload add a single-app-role mapping, a pgcrypto secrets impl, and identity wiring. The better-auth id-format mismatch is resolved by an install-time `--better-auth-ids uuid|mapped` flag that selects which SQL is emitted — no runtime detection. A plain-Postgres CI load test guards against regression.

**Tech Stack:** PostgreSQL 18, plain `.sql` files concatenated by `packages/cli/deploy.js` (and the identical `scripts/combine_files.js`), pgTap + `pg_prove` for tests, pgcrypto, TypeScript (`pg`) middleware, Docker (`postgres:18`) for the CI load gate, GitHub Actions.

## Global Constraints

- Target runtime: **vanilla PostgreSQL 18** (no Supabase, GoTrue, PostgREST, Vault, pg_graphql).
- Core must contain **zero** references to `auth.uid()`, `auth.users`, `authenticated`, `anon`, or `service_role`.
- Neutral role names are exactly **`app_user`** (NOLOGIN, RLS-subject — no BYPASSRLS) and **`app_admin`** (NOLOGIN, BYPASSRLS).
- RLS model is unchanged: policies key off `core.get_current_user_id()`, not the connected role. The runtime backend connects as `app_user` (RLS applies); migrations/seed as `app_admin`.
- Session variable name is exactly **`app.current_user_id`** (already used by all non-Supabase adapters).
- `core.store_secret_impl` must return a value castable to `UUID` (stored in `platform.tenant_secrets.vault_key_id`, a UUID column).
- Better-auth id flag is exactly `--better-auth-ids` with values `uuid` or `mapped`; **required** when `--adapter better-auth`.
- Two build entry points must stay in sync: `packages/cli/deploy.js` and `scripts/combine_files.js`. Every CLI change applies to **both**.
- Commit messages: **no `Co-Authored-By` trailer** (project convention).
- Work happens on branch `desupabase-core-better-auth` (already created).

---

## Phase 0 — Plain-Postgres load gate (the driving test)

This phase builds the failing system-level test that the whole plan makes pass: deploy each non-Supabase adapter against stock Postgres and assert a clean load.

### Task 0.1: Plain-Postgres load-test script

**Files:**
- Create: `scripts/test-plain-postgres-load.sh`

**Interfaces:**
- Produces: a script that takes an SQL file path (`$1`) and a Docker container name (`$2`), applies the file in one `ON_ERROR_STOP=1 --single-transaction` psql run inside a stock `postgres:18` container, and exits non-zero on any error. Used by Tasks 5.x, 6.x, and the CI workflow (Task 7.5).

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# test-plain-postgres-load.sh
# Applies a generated SMTA SQL file against a stock postgres:18 container in a
# single rolled-forward transaction with ON_ERROR_STOP. Exits non-zero on any
# load error (undefined role, missing auth.*, etc). Nothing is left committed
# because we drop the database afterward.
#
# Usage: scripts/test-plain-postgres-load.sh <sql-file> <container-name>
set -euo pipefail

SQL_FILE="${1:?usage: test-plain-postgres-load.sh <sql-file> <container-name>}"
CONTAINER="${2:?usage: test-plain-postgres-load.sh <sql-file> <container-name>}"
DB="smta_load_test"

if [ ! -f "$SQL_FILE" ]; then
  echo "ERROR: SQL file not found: $SQL_FILE" >&2
  exit 2
fi

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=postgres postgres:18 >/dev/null

# Wait for readiness (max ~30s)
for i in $(seq 1 30); do
  if docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done

docker exec "$CONTAINER" psql -U postgres -c "CREATE DATABASE $DB" >/dev/null

echo "Applying $SQL_FILE ..."
docker exec -i "$CONTAINER" psql -U postgres -d "$DB" \
  -v ON_ERROR_STOP=1 --single-transaction < "$SQL_FILE"

echo "OK: $SQL_FILE loaded cleanly on vanilla PostgreSQL 18"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/test-plain-postgres-load.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Verify it FAILS against today's better-auth output**

Run:
```bash
node ./scripts/combine_files.js --adapter better-auth
./scripts/test-plain-postgres-load.sh "$(ls -t SMTA-better-auth-*.sql | head -1)" smta-load-baseline
```
Expected: **FAIL** — psql aborts with `ERROR: role "authenticated" does not exist` (confirms the gate detects the current breakage). If `--adapter better-auth` errors on the missing `--better-auth-ids` flag, that flag does not exist yet; instead run `npm run build:better-auth` (current behavior emits the broken file) and load that. Document the exact failure observed.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-plain-postgres-load.sh
git commit -m "test: add plain-postgres load gate script (currently failing for better-auth)"
```

---

## Phase 1 — De-Supabase `@smta/core`

After this phase, `@smta/core` alone loads on vanilla Postgres. Because the full adapter output still includes Supabase add-backs that are not yet adjusted, the *combined* better-auth file is made to pass in Phase 5; here we verify **core-only**.

### Task 1.1: Neutral roles + schema grants in `init/schemas.sql`

**Files:**
- Modify: `packages/core/sql/init/schemas.sql`

**Interfaces:**
- Produces: roles `app_user` (NOLOGIN, no BYPASSRLS) and `app_admin` (NOLOGIN, BYPASSRLS), created before any GRANT. All later core grants target these.

- [ ] **Step 1: Replace the ACCESS CONTROL + DEFAULT PRIVILEGES + platform-revoke block.**

Replace lines 23–43 (everything from `-- ACCESS CONTROL` through the two platform `REVOKE` lines) with:

```sql
-- ========================================
-- NEUTRAL APPLICATION ROLES
-- ========================================
-- SMTA core is adapter-agnostic. It owns two neutral roles:
--   app_user  — the runtime identity the application backend assumes.
--               RLS-subject (NOT BYPASSRLS): row access is enforced via
--               core.get_current_user_id() reading app.current_user_id.
--   app_admin — migrations/seed/admin DML. BYPASSRLS.
-- Adapters map their reality onto these (e.g. the supabase adapter grants
-- app_user TO authenticated and app_admin TO service_role).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user')  THEN CREATE ROLE app_user  NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_admin') THEN CREATE ROLE app_admin NOLOGIN BYPASSRLS; END IF;
END $$;

-- ========================================
-- ACCESS CONTROL
-- ========================================
GRANT USAGE ON SCHEMA utils TO app_user;
GRANT USAGE ON SCHEMA core  TO app_user;
GRANT USAGE ON SCHEMA app   TO app_user;

GRANT USAGE ON SCHEMA utils TO app_admin;
GRANT USAGE ON SCHEMA core  TO app_admin;
GRANT USAGE ON SCHEMA app   TO app_admin;

-- ========================================
-- DEFAULT TABLE PRIVILEGES
-- ========================================
-- NOTE: SMTA intentionally does NOT set default privileges on the shared `app`
-- schema (finding C10). The consuming project owns `app` table privileges.
ALTER DEFAULT PRIVILEGES IN SCHEMA utils GRANT SELECT ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA core  GRANT SELECT ON TABLES TO app_user;

-- Lock down platform schema to prevent tenant access.
REVOKE ALL ON SCHEMA platform FROM app_user, PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM app_user, PUBLIC;
```

- [ ] **Step 2: Verify no Supabase identifiers remain in this file**

Run: `grep -nE "authenticated|anon|service_role|auth\." packages/core/sql/init/schemas.sql`
Expected: no matches (exit 1 / empty output).

- [ ] **Step 3: Commit**

```bash
git add packages/core/sql/init/schemas.sql
git commit -m "feat(core): create neutral app_user/app_admin roles; drop supabase roles from schemas"
```

### Task 1.2: Core table grants → neutral roles

**Files:**
- Modify: `packages/core/sql/tables/grants.sql`

- [ ] **Step 1: Replace the role names.** In `packages/core/sql/tables/grants.sql`, change every `TO authenticated` to `TO app_user` and every `TO service_role` to `TO app_admin` (lines 11–21, 29, 35–36). Update the SERVICE ROLE comment block to read:

```sql
-- ========================================
-- ADMIN ROLE PERMISSIONS
-- ========================================
-- app_admin has full DML on core tables for migrations, seed scripts, and
-- admin backend operations. app_admin has BYPASSRLS, so RLS does not apply to it.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO app_admin;
```

- [ ] **Step 2: Verify**

Run: `grep -nE "authenticated|service_role|anon" packages/core/sql/tables/grants.sql`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add packages/core/sql/tables/grants.sql
git commit -m "feat(core): grant core tables to app_user/app_admin"
```

### Task 1.3: Public function EXECUTE grants → neutral roles

**Files:**
- Modify: `packages/core/sql/public/grants.sql`

- [ ] **Step 1: Rewrite the admin-function grants.** Replace each pair of lines (currently `REVOKE … FROM PUBLIC, anon;` then `GRANT … TO authenticated, service_role;`) so the REVOKE drops the `, anon` (revoking from `PUBLIC` already covers unauthenticated callers) and the GRANT targets `app_user, app_admin`. The six functions and their exact signatures:

```sql
REVOKE EXECUTE ON FUNCTION public.delete_organization(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_organization(uuid) TO app_user, app_admin;

REVOKE EXECUTE ON FUNCTION public.delete_unit(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_unit(uuid) TO app_user, app_admin;

REVOKE EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_member_to_organization(uuid, uuid, uuid) TO app_user, app_admin;

REVOKE EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_member_to_unit(uuid, uuid, uuid) TO app_user, app_admin;

REVOKE EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_organization(uuid, uuid) TO app_user, app_admin;

REVOKE EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_unit(uuid, uuid) TO app_user, app_admin;
```

Update the header comment: replace the Supabase-lint references and the "GRANT to authenticated + service_role" sentence with "GRANT to app_user + app_admin"; the two public-by-design functions still keep their default PUBLIC EXECUTE grant (leave that section as prose).

- [ ] **Step 2: Verify**

Run: `grep -nE "authenticated|service_role|anon" packages/core/sql/public/grants.sql`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add packages/core/sql/public/grants.sql
git commit -m "feat(core): execute grants on public admin functions to app_user/app_admin"
```

### Task 1.4: Platform table grants → neutral roles

**Files:**
- Modify: `packages/core/sql/platform/tables/grants.sql`

- [ ] **Step 1: Replace role names.** Change `authenticated, anon, PUBLIC` → `app_user, PUBLIC` in the three `REVOKE … FROM` lines (18–20); change the two `ALTER DEFAULT PRIVILEGES … FROM authenticated` lines (23–24) to `FROM app_user`; change the four `service_role` grants/default-privs (30–34) to `app_admin`. Update comments referencing `service_role`/`authenticated` to `app_admin`/`app_user`.

- [ ] **Step 2: Verify**

Run: `grep -nE "authenticated|service_role|anon" packages/core/sql/platform/tables/grants.sql`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add packages/core/sql/platform/tables/grants.sql
git commit -m "feat(core): platform schema lockdown/grants use app_user/app_admin"
```

### Task 1.5: Replace `auth.uid()` in core function bodies

**Files:**
- Modify: `packages/core/sql/platform/functions/settings.sql` (lines 61, 99)
- Modify: `packages/core/sql/platform/functions/products.sql` (lines 103, 104)
- Modify: `packages/core/sql/platform/functions/feature_flags.sql` (lines 19, 106, 134)
- Modify: `packages/core/sql/platform/functions/users.sql` (lines 21, 99, 165 — the `v_actor_id := auth.uid();` assignments only; the `auth.users` checks are handled in Task 1.7)
- Modify: `packages/core/sql/tables/audit_logs.sql` (line 9 — comment only)
- Modify: `packages/core/sql/public/functions/secrets.sql` (lines 23, 77 — doc-comment examples only)

- [ ] **Step 1: Replace each executable `auth.uid()` with `core.get_current_user_id()`.** In settings.sql, products.sql, feature_flags.sql, and the three `v_actor_id := auth.uid();` lines in users.sql, replace `auth.uid()` with `core.get_current_user_id()`. In audit_logs.sql line 9 change the comment `-- auth.uid()` to `-- core.get_current_user_id()`. In public/functions/secrets.sql replace `auth.uid()` with `core.get_current_user_id()` inside the two `--   SELECT …` example comments.

- [ ] **Step 2: Verify only the lockdown.sql/log_action.sql/audit.sql sites remain (handled next)**

Run: `grep -rn "auth.uid()" packages/core/sql/`
Expected: matches ONLY in `platform/rls/lockdown.sql`, `platform/functions/log_action.sql`, and `platform/functions/audit.sql` (addressed in Tasks 1.6–1.7).

- [ ] **Step 3: Commit**

```bash
git add packages/core/sql/platform/functions/settings.sql packages/core/sql/platform/functions/products.sql packages/core/sql/platform/functions/feature_flags.sql packages/core/sql/platform/functions/users.sql packages/core/sql/tables/audit_logs.sql packages/core/sql/public/functions/secrets.sql
git commit -m "feat(core): replace auth.uid() with core.get_current_user_id() in function bodies"
```

### Task 1.6: De-Supabase `platform/rls/lockdown.sql`

**Files:**
- Modify: `packages/core/sql/platform/rls/lockdown.sql`

**Interfaces:**
- Produces: `platform.is_platform_user()` / `platform.is_platform_super_admin()` resolving via `platform.platform_users.user_id = core.get_current_user_id()`. All platform RLS policies target `app_user`.

- [ ] **Step 1: Fix the two guard functions.** In `platform.is_platform_user()` (line 12) and `platform.is_platform_super_admin()` (line 28), change `pu.supabase_user_id = auth.uid()` to `pu.user_id = core.get_current_user_id()`. Add `core` to the `SET search_path` of both functions (`SET search_path = platform, core, public`).

- [ ] **Step 2: Retarget all policy role clauses.** Replace every occurrence of `FOR SELECT TO authenticated`, `FOR INSERT TO authenticated`, and `FOR UPDATE TO authenticated` with the same clause using `app_user` (e.g. `FOR SELECT TO app_user`). There are ~40 occurrences across this file.

Run this to do it mechanically, then eyeball the diff:
```bash
sed -i 's/ TO authenticated$/ TO app_user/' packages/core/sql/platform/rls/lockdown.sql
```

- [ ] **Step 3: Verify**

Run: `grep -nE "auth\.uid\(\)|authenticated|supabase_user_id" packages/core/sql/platform/rls/lockdown.sql`
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add packages/core/sql/platform/rls/lockdown.sql
git commit -m "feat(core): platform RLS guards/policies use core.get_current_user_id() + app_user"
```

### Task 1.7: De-Supabase `platform.*` identity columns and functions

**Files:**
- Modify: `packages/core/sql/platform/tables/users.sql` (line 9 column + line 2 comment; line 192-area index in generated output)
- Modify: `packages/core/sql/platform/tables/action_logs.sql` (line 10 FK)
- Modify: `packages/core/sql/platform/functions/users.sql` (rename param, drop `auth.users` checks)
- Modify: `packages/core/sql/platform/functions/log_action.sql` (lines 24–25)
- Modify: `packages/core/sql/platform/functions/audit.sql` (line 18)

**Interfaces:**
- Produces: `platform.platform_users.user_id UUID` (was `supabase_user_id`, FK to `auth.users` removed); `platform.create_platform_user(p_user_id UUID, p_email TEXT, p_role_id UUID)`; validation against `core.users_meta` instead of `auth.users`.

- [ ] **Step 1: `platform/tables/users.sql` — rename column, drop FK.** Change line 9 from
```sql
  supabase_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
```
to
```sql
  user_id UUID UNIQUE NOT NULL,
```
Change the file-purpose comment (line 2) to "Platform admin users table (user_id references the adapter's user identity)." Change the `CREATE INDEX ON platform.platform_users (supabase_user_id);` to `(user_id)`.

- [ ] **Step 2: `platform/tables/action_logs.sql` — fix FK target.** Change line 10 from
```sql
  auth_user_id UUID REFERENCES platform.platform_users(supabase_user_id),
```
to
```sql
  auth_user_id UUID REFERENCES platform.platform_users(user_id),
```

- [ ] **Step 3: `platform/functions/users.sql` — primary `create_platform_user`.** Rename the parameter `p_supabase_user_id` → `p_user_id` (signature stays `(UUID, TEXT, UUID)`). Replace `v_actor_id := auth.uid();` (line 21) with `v_actor_id := core.get_current_user_id();`. Replace the existence check (lines 23–25, 31–33) with a `core.users_meta` check:
```sql
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RAISE EXCEPTION 'email is required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM core.users_meta um WHERE um.id = p_user_id) THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;
```
Update the `INSERT INTO platform.platform_users (supabase_user_id, …)` to `(user_id, …)` and the `jsonb_build_object('…','supabase_user_id', p_supabase_user_id,…)` key to `'user_id', p_user_id`. Add `core` to `SET search_path` (`SET search_path = platform, core`).

- [ ] **Step 4: `platform/functions/users.sql` — legacy wrapper + the other two functions.** In the legacy `create_platform_user(p_user_id UUID, p_role TEXT)`, replace the `SELECT u.email … FROM auth.users u WHERE u.id = p_user_id;` block (lines 73–79) with:
```sql
  SELECT um.email INTO v_email
  FROM core.users_meta um
  WHERE um.id = p_user_id;

  IF v_email IS NULL THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;
```
In `update_platform_user` (line 99) and `delete_platform_user` (line 165), replace `v_actor_id := auth.uid();` with `v_actor_id := core.get_current_user_id();`. Add `core` to each function's `SET search_path`.

- [ ] **Step 5: `platform/functions/log_action.sql` lines 24–25.** Replace
```sql
    (SELECT id FROM platform.platform_users WHERE supabase_user_id = auth.uid()),
    auth.uid(),
```
with
```sql
    (SELECT id FROM platform.platform_users WHERE user_id = core.get_current_user_id()),
    core.get_current_user_id(),
```
Add `core` to its `SET search_path`.

- [ ] **Step 6: `platform/functions/audit.sql` line 18.** Replace `WHERE pu.supabase_user_id = auth.uid()` with `WHERE pu.user_id = core.get_current_user_id()`. Add `core` to its `SET search_path`.

- [ ] **Step 7: Verify all Supabase identity references are gone from core.**

Run:
```bash
grep -rnE "auth\.uid\(\)|auth\.users|supabase_user_id" packages/core/sql/ | grep -vE "^\S+:[0-9]+:\s*--"
```
Expected: no matches (any remaining hits must be comments only). Then also check comments:
```bash
grep -rn "supabase_user_id" packages/core/sql/
```
Expected: no matches at all (including comments).

- [ ] **Step 8: Commit**

```bash
git add packages/core/sql/platform/
git commit -m "feat(core): rename supabase_user_id->user_id, validate via core.users_meta, drop auth.users"
```

### Task 1.8: Remove the `auth.users` signup trigger and `auth.users` FK reference from core

**Files:**
- Modify: `packages/core/sql/triggers/new_user.sql`
- Modify: `packages/core/sql/platform/tables/tenant_secrets.sql` (line 12 — `user_id UUID REFERENCES auth.users(id)`)
- Modify: `packages/core/sql/public/functions/organizations.sql` (the `invite_user_to_organization` lookup `FROM auth.users`)

**Interfaces:**
- Produces: `core.handle_new_user()` retained as a reusable function body (adapters attach their own trigger); no `CREATE TRIGGER ON auth.users` in core; `platform.tenant_secrets.user_id` has no FK in core (the supabase adapter restores it).

- [ ] **Step 1: `triggers/new_user.sql` — keep function, drop the auth.users trigger.** Remove the trigger block (the `DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;` and the `CREATE TRIGGER … AFTER INSERT ON auth.users …` statement). Keep `core.handle_new_user()`. Update the NOTES to state the trigger that fires it is supplied by each adapter (supabase: on `auth.users`; better-auth: on `"user"`).

- [ ] **Step 2: `platform/tables/tenant_secrets.sql` line 12.** Change
```sql
  user_id UUID REFERENCES auth.users(id),
```
to
```sql
  user_id UUID,
```
Add a comment: `-- FK to the adapter's user identity is restored by the supabase adapter (constraints.sql).`

- [ ] **Step 3: `public/functions/organizations.sql` — `invite_user_to_organization`.** Replace
```sql
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
```
with
```sql
  SELECT id INTO v_user_id FROM core.users_meta WHERE email = p_email;
```
(Keep the surrounding `IF v_user_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;`.)

- [ ] **Step 4: Verify core is fully de-Supabased.**

Run: `grep -rnE "auth\.uid|auth\.users|authenticated|\banon\b|service_role" packages/core/sql/`
Expected: no matches anywhere (comments included). If any remain in a doc comment, scrub them.

- [ ] **Step 5: Commit**

```bash
git add packages/core/sql/triggers/new_user.sql packages/core/sql/platform/tables/tenant_secrets.sql packages/core/sql/public/functions/organizations.sql
git commit -m "feat(core): drop auth.users trigger/FK/lookups; adapters own user wiring"
```

### Task 1.9: Move `pg_graphql` disable out of core; add `read_secret_impl` to the secrets interface

**Files:**
- Modify: `packages/core/sql-scripts.json` (remove the graphql line)
- Modify: `packages/core/sql/init/secrets_interface.sql` (add `read_secret_impl` stub)

**Interfaces:**
- Produces: secrets interface trio `store_secret_impl(TEXT, TEXT) RETURNS TEXT`, `delete_secret_impl(TEXT) RETURNS VOID`, `read_secret_impl(TEXT) RETURNS TEXT`. Consumed by Task 3.x (pgcrypto) and Task 2.x (supabase Vault).

- [ ] **Step 1: Remove the graphql script from core's manifest.** In `packages/core/sql-scripts.json`, delete the line `"sql/graphql/disable_extension.sql"`. (The file stays on disk; the supabase manifest will reference it in Task 2.3.)

- [ ] **Step 2: Add the `read_secret_impl` stub** to `packages/core/sql/init/secrets_interface.sql`, after `delete_secret_impl`:
```sql
-- Called to retrieve a secret's plaintext by its reference ID.
CREATE OR REPLACE FUNCTION core.read_secret_impl(p_secret_ref TEXT)
RETURNS TEXT AS $$
BEGIN
  RAISE EXCEPTION 'core.read_secret_impl() not implemented. Deploy an adapter.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;
```

- [ ] **Step 3: Build core-only SQL and load it on plain Postgres.**

Run:
```bash
# Emit core scripts only by concatenating the manifest (no adapter):
node -e "const fs=require('fs'),p=require('path');const d='packages/core';const m=JSON.parse(fs.readFileSync(p.join(d,'sql-scripts.json')));const out=m.scripts.map(f=>fs.readFileSync(p.join(d,f),'utf8')).join('\n\n-- NEW FILE --\n\n');fs.writeFileSync('/tmp/core-only.sql',out)"
./scripts/test-plain-postgres-load.sh /tmp/core-only.sql smta-core-load
```
Expected: **`OK: /tmp/core-only.sql loaded cleanly on vanilla PostgreSQL 18`**. If it fails, the error names the remaining Supabase coupling — fix it in the relevant Phase-1 file before continuing.

- [ ] **Step 4: Commit**

```bash
git add packages/core/sql-scripts.json packages/core/sql/init/secrets_interface.sql
git commit -m "feat(core): drop graphql from core manifest; add read_secret_impl interface stub"
```

---

## Phase 2 — Supabase adapter add-backs (no behavior regression)

### Task 2.1: Map neutral roles to Supabase roles

**Files:**
- Create: `packages/supabase/sql/grants_role_mapping.sql`
- Modify: `packages/supabase/sql-scripts.json`

**Interfaces:**
- Consumes: core roles `app_user`, `app_admin`.
- Produces: `authenticated`/`service_role` inherit core privileges via role membership.

- [ ] **Step 1: Create the mapping file.**
```sql
-- grants_role_mapping.sql
-- Purpose: Map SMTA core's neutral roles onto Supabase's GoTrue roles so that
-- privileges granted to app_user/app_admin in core apply to Supabase connections.
-- authenticated -> app_user (RLS-subject); service_role -> app_admin (BYPASSRLS).
GRANT app_user  TO authenticated;
GRANT app_admin TO service_role;
```

- [ ] **Step 2: Register it in the supabase manifest** as the FIRST script (so the mapping exists before later supabase grants), by adding `"sql/grants_role_mapping.sql"` at the top of the `scripts` array in `packages/supabase/sql-scripts.json`.

- [ ] **Step 3: Commit**

```bash
git add packages/supabase/sql/grants_role_mapping.sql packages/supabase/sql-scripts.json
git commit -m "feat(supabase): map app_user/app_admin onto authenticated/service_role"
```

### Task 2.2: Restore `auth.users` FKs + signup trigger in the supabase adapter

**Files:**
- Modify: `packages/supabase/sql/constraints.sql`
- Create: `packages/supabase/sql/new_user_trigger.sql`
- Modify: `packages/supabase/sql-scripts.json`

**Interfaces:**
- Consumes: `platform.platform_users.user_id`, `platform.tenant_secrets.user_id`, `core.handle_new_user()`.
- Produces: Supabase-only FKs to `auth.users` and the `auth.users` AFTER INSERT trigger.

- [ ] **Step 1: Add the two FKs core no longer creates** to `packages/supabase/sql/constraints.sql` (append after the existing constraints):
```sql
-- Platform identity FKs (core dropped these for adapter-agnosticism).
ALTER TABLE platform.platform_users
  ADD CONSTRAINT fk_platform_users_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE platform.tenant_secrets
  ADD CONSTRAINT fk_tenant_secrets_auth_users
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
```

- [ ] **Step 2: Create the supabase signup trigger** `packages/supabase/sql/new_user_trigger.sql`:
```sql
-- new_user_trigger.sql
-- Purpose: Attach core.handle_new_user() to Supabase's auth.users table.
-- Core defines the function but is adapter-agnostic and does not bind it.
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION core.handle_new_user();
```

- [ ] **Step 3: Register the trigger file** in `packages/supabase/sql-scripts.json` (after `constraints.sql`).

- [ ] **Step 4: Commit**

```bash
git add packages/supabase/sql/constraints.sql packages/supabase/sql/new_user_trigger.sql packages/supabase/sql-scripts.json
git commit -m "feat(supabase): restore auth.users FKs and signup trigger removed from core"
```

### Task 2.3: Keep `pg_graphql` disable + Vault `read_secret_impl` in the supabase adapter

**Files:**
- Modify: `packages/supabase/sql-scripts.json`
- Modify: `packages/supabase/sql/init/secrets_supabase_impl.sql`
- Modify: `packages/cli/deploy.js` and `scripts/combine_files.js` (the `--enable-graphql` filter path)

**Interfaces:**
- Produces: supabase manifest includes `../core/sql/graphql/disable_extension.sql`? No — manifests reference files within their own package. Instead copy the disable file into the supabase package.

- [ ] **Step 1: Move the graphql disable file into the supabase package.**

Run:
```bash
git mv packages/core/sql/graphql/disable_extension.sql packages/supabase/sql/disable_graphql.sql
```

- [ ] **Step 2: Update the `--enable-graphql` filter** in BOTH `packages/cli/deploy.js` (line ~51) and `scripts/combine_files.js`. Change the path it filters on from `path.join('graphql', 'disable_extension.sql')` to `'disable_graphql.sql'` so the flag still suppresses the (now supabase-owned) file.

- [ ] **Step 3: Register `sql/disable_graphql.sql`** as the LAST script in `packages/supabase/sql-scripts.json`.

- [ ] **Step 4: Add the Vault `read_secret_impl`** to `packages/supabase/sql/init/secrets_supabase_impl.sql`:
```sql
CREATE OR REPLACE FUNCTION core.read_secret_impl(p_secret_ref TEXT)
RETURNS TEXT AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE id = p_secret_ref::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, vault, public;
```

- [ ] **Step 5: Commit**

```bash
git add -A packages/supabase packages/cli/deploy.js scripts/combine_files.js
git commit -m "feat(supabase): own pg_graphql disable + Vault read_secret_impl"
```

---

## Phase 3 — pgcrypto secrets implementation (shared by better-auth + payload)

### Task 3.1: Create the pgcrypto secrets impl file

**Files:**
- Create: `packages/better-auth/sql/init/secrets_pgcrypto_impl.sql`

**Interfaces:**
- Consumes: secrets interface (`store_secret_impl`, `delete_secret_impl`, `read_secret_impl`).
- Produces: a pgcrypto-backed implementation keyed by UUID; encryption key from `current_setting('app.secrets_key')`.

- [ ] **Step 1: Write the impl.**
```sql
-- secrets_pgcrypto_impl.sql
-- Purpose: Non-Supabase secrets provider. Encrypts secret values with pgcrypto
-- (pgp_sym_encrypt) into core.encrypted_secrets, keyed by a generated UUID so the
-- reference is castable to UUID (stored in platform.tenant_secrets.vault_key_id).
-- The symmetric key is read from the GUC app.secrets_key, set by the backend per
-- session/connection. It is never hard-coded in SQL.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS core.encrypted_secrets (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT,
  ciphertext BYTEA NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION core.store_secret_impl(p_secret TEXT, p_name TEXT DEFAULT NULL)
RETURNS TEXT AS $$
DECLARE
  v_key TEXT := NULLIF(current_setting('app.secrets_key', true), '');
  v_id  UUID;
BEGIN
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'app.secrets_key is not set; cannot encrypt secret';
  END IF;
  INSERT INTO core.encrypted_secrets (name, ciphertext)
  VALUES (p_name, pgp_sym_encrypt(p_secret, v_key))
  RETURNING id INTO v_id;
  RETURN v_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;

CREATE OR REPLACE FUNCTION core.read_secret_impl(p_secret_ref TEXT)
RETURNS TEXT AS $$
DECLARE
  v_key TEXT := NULLIF(current_setting('app.secrets_key', true), '');
BEGIN
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'app.secrets_key is not set; cannot decrypt secret';
  END IF;
  RETURN (SELECT pgp_sym_decrypt(ciphertext, v_key) FROM core.encrypted_secrets WHERE id = p_secret_ref::UUID);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = core;

CREATE OR REPLACE FUNCTION core.delete_secret_impl(p_secret_ref TEXT)
RETURNS VOID AS $$
  DELETE FROM core.encrypted_secrets WHERE id = p_secret_ref::UUID;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = core;
```

- [ ] **Step 2: Commit**

```bash
git add packages/better-auth/sql/init/secrets_pgcrypto_impl.sql
git commit -m "feat: pgcrypto secrets implementation for non-supabase adapters"
```

### Task 3.2: Share the pgcrypto impl with payload

**Files:**
- Create: `packages/payload/sql/init/secrets_pgcrypto_impl.sql` (copy)

**Interfaces:**
- Note: manifests can only reference files inside their own package, so the pgcrypto impl is duplicated into payload. Keep the two files byte-identical.

- [ ] **Step 1: Copy the file into payload.**

Run: `cp packages/better-auth/sql/init/secrets_pgcrypto_impl.sql packages/payload/sql/init/secrets_pgcrypto_impl.sql`

- [ ] **Step 2: Add a sync guard test.** Create `tests/adapters/02_secrets_impl_in_sync.sh`:
```bash
#!/usr/bin/env bash
# Ensures the pgcrypto secrets impl stays identical across non-supabase adapters.
set -euo pipefail
diff packages/better-auth/sql/init/secrets_pgcrypto_impl.sql \
     packages/payload/sql/init/secrets_pgcrypto_impl.sql \
  && echo "OK: pgcrypto secrets impl in sync"
```
Run: `chmod +x tests/adapters/02_secrets_impl_in_sync.sh && ./tests/adapters/02_secrets_impl_in_sync.sh`
Expected: `OK: pgcrypto secrets impl in sync`.

- [ ] **Step 3: Commit**

```bash
git add packages/payload/sql/init/secrets_pgcrypto_impl.sql tests/adapters/02_secrets_impl_in_sync.sh
git commit -m "feat(payload): pgcrypto secrets impl (in sync with better-auth)"
```

---

## Phase 4 — CLI `--better-auth-ids` flag

### Task 4.1: Add the required flag + variant selection to both build entry points

**Files:**
- Modify: `packages/cli/deploy.js`
- Modify: `scripts/combine_files.js`
- Modify: `package.json` (the `build:better-auth` script)

**Interfaces:**
- Consumes: `packages/better-auth/sql-scripts.json` will declare per-mode scripts (Task 5.x).
- Produces: `--better-auth-ids <uuid|mapped>`; required when `--adapter better-auth`; error otherwise. Passed to manifest resolution as a variant key.

- [ ] **Step 1: Inspect the current arg parsing in `packages/cli/deploy.js` (lines 28–53)** so the new flag matches the existing style (it reads `--adapter` and `--enable-graphql`).

- [ ] **Step 2: Add flag parsing + validation in `deploy.js`.** After the adapter validation block (after line 41), insert:
```js
  let betterAuthIds = null
  if (adapterName === 'better-auth') {
    const idsIdx = process.argv.indexOf('--better-auth-ids')
    betterAuthIds = idsIdx !== -1 ? process.argv[idsIdx + 1] : null
    if (!betterAuthIds || !['uuid', 'mapped'].includes(betterAuthIds)) {
      console.error(
        '--adapter better-auth requires --better-auth-ids <uuid|mapped>.\n' +
        "  uuid   = Better-Auth configured to emit UUID ids (advanced.database.generateId). Fastest; no mapping table.\n" +
        '  mapped = SMTA maps Better-Auth string ids to UUIDs via core.user_identities (no Better-Auth config).'
      )
      process.exit(1)
    }
  }
```

- [ ] **Step 3: Pass the variant into manifest resolution.** Change `readPackageScripts(adapterDir)` for the better-auth case to filter by variant. Update `readPackageScripts` to accept an optional `variant` and, when the manifest entry is an object `{ variant: "uuid", file: "..." }`, include it only if `variant` matches or is absent. Replace the function with:
```js
async function readPackageScripts(packageDir, variant) {
  const manifestPath = path.join(packageDir, 'sql-scripts.json')
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
  if (!Array.isArray(manifest.scripts)) {
    throw new Error(`sql-scripts.json in ${packageDir} is missing a "scripts" array`)
  }
  return manifest.scripts
    .map(entry => (typeof entry === 'string' ? { file: entry } : entry))
    .filter(entry => !entry.variant || entry.variant === variant)
    .map(entry => {
      if (path.isAbsolute(entry.file) || entry.file.includes('..')) {
        throw new Error(`Unsafe path in sql-scripts.json: "${entry.file}"`)
      }
      return path.join(packageDir, entry.file)
    })
}
```
Update the call site to `await readPackageScripts(adapterDir, betterAuthIds)` and core's call to `await readPackageScripts(coreDir)`.

- [ ] **Step 4: Mirror Steps 2–3 verbatim into `scripts/combine_files.js`** (it has the same structure).

- [ ] **Step 5: Update `package.json`** so `build:better-auth` is split:
```json
    "build:better-auth:uuid": "node ./scripts/combine_files.js --adapter better-auth --better-auth-ids uuid",
    "build:better-auth:mapped": "node ./scripts/combine_files.js --adapter better-auth --better-auth-ids mapped",
    "build:better-auth": "npm run build:better-auth:uuid && npm run build:better-auth:mapped",
```

- [ ] **Step 6: Verify the flag is enforced.**

Run: `node ./scripts/combine_files.js --adapter better-auth`
Expected: exits non-zero with the `--better-auth-ids` usage message.

- [ ] **Step 7: Commit**

```bash
git add packages/cli/deploy.js scripts/combine_files.js package.json
git commit -m "feat(cli): require --better-auth-ids <uuid|mapped> and select SQL variant"
```

---

## Phase 5 — Better-Auth adapter (both id modes)

### Task 5.1: Role mapping + split the auth/secrets/trigger SQL into uuid vs mapped variants

**Files:**
- Create: `packages/better-auth/sql/init/roles.sql`
- Create: `packages/better-auth/sql/init/auth_impl_uuid.sql`
- Create: `packages/better-auth/sql/init/auth_impl_mapped.sql`
- Create: `packages/better-auth/sql/init/new_user_trigger_uuid.sql`
- Create: `packages/better-auth/sql/init/new_user_trigger_mapped.sql`
- Delete: `packages/better-auth/sql/init/auth_better_auth_impl.sql`, `packages/better-auth/sql/init/new_user_trigger.sql`
- Modify: `packages/better-auth/sql-scripts.json`

**Interfaces:**
- Consumes: core roles `app_user`/`app_admin`; `core.users_meta`; `core.handle_new_user()`.
- Produces (uuid): `core.get_current_user_id()` = `current_setting(...)::UUID`; trigger inserts `NEW.id::UUID`.
- Produces (mapped): `core.user_identities(external_id TEXT PK, user_id UUID UNIQUE DEFAULT gen_random_uuid())`; `core.get_current_user_id()` resolves via that table; trigger mints UUID + writes both rows.

- [ ] **Step 1: Create `roles.sql`** (the better-auth backend connects as `app_user`; migrations as `app_admin`). Since plain Postgres has no GoTrue roles, the deployer's app role must be a member of `app_user`. Provide a documented default that grants membership to a conventionally-named login role if it exists, and is otherwise a no-op:
```sql
-- roles.sql
-- Purpose: In a Better-Auth / plain-Postgres deployment there is no GoTrue role
-- trio. The application backend connects as a single login role that must inherit
-- app_user (RLS-subject). Migrations connect as a role inheriting app_admin.
-- This file is a documented hook: set app.app_login_role / app.admin_login_role
-- GUCs at deploy time to auto-wire membership, else wire it manually post-deploy.
DO $$
DECLARE
  v_app   TEXT := NULLIF(current_setting('smta.app_login_role',   true), '');
  v_admin TEXT := NULLIF(current_setting('smta.admin_login_role', true), '');
BEGIN
  IF v_app   IS NOT NULL THEN EXECUTE format('GRANT app_user  TO %I', v_app);   END IF;
  IF v_admin IS NOT NULL THEN EXECUTE format('GRANT app_admin TO %I', v_admin); END IF;
END $$;
```

- [ ] **Step 2: Create `auth_impl_uuid.sql`:**
```sql
-- auth_impl_uuid.sql
-- Better-Auth UUID mode: ids are already UUIDs (advanced.database.generateId).
-- get_current_user_id() reads the UUID straight from the session variable.
CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

- [ ] **Step 3: Create `auth_impl_mapped.sql`:**
```sql
-- auth_impl_mapped.sql
-- Better-Auth mapped mode: Better-Auth ids are arbitrary strings. SMTA mints its
-- own UUID per user and resolves external_id -> user_id on each call.
CREATE TABLE IF NOT EXISTS core.user_identities (
  external_id TEXT PRIMARY KEY,
  user_id     UUID NOT NULL UNIQUE DEFAULT gen_random_uuid()
);

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT user_id
  FROM core.user_identities
  WHERE external_id = NULLIF(current_setting('app.current_user_id', true), '');
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

- [ ] **Step 4: Create `new_user_trigger_uuid.sql`** (the function casts `NEW.id::UUID`; the conditional trigger attach is unchanged from today's `new_user_trigger.sql`, plus keep the `fk_users_meta_auth_users` drop guard):
```sql
-- new_user_trigger_uuid.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_meta_auth_users'
             AND conrelid = 'core.users_meta'::regclass) THEN
    ALTER TABLE core.users_meta DROP CONSTRAINT fk_users_meta_auth_users;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = core AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id::UUID, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user') THEN
    DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
    CREATE TRIGGER trg_on_better_auth_user_created
    AFTER INSERT ON "user"
    FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();
  END IF;
END $$;
```

- [ ] **Step 5: Create `new_user_trigger_mapped.sql`** (mint UUID, write mapping + users_meta):
```sql
-- new_user_trigger_mapped.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_meta_auth_users'
             AND conrelid = 'core.users_meta'::regclass) THEN
    ALTER TABLE core.users_meta DROP CONSTRAINT fk_users_meta_auth_users;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = core AS $$
DECLARE
  v_uuid UUID;
BEGIN
  INSERT INTO core.user_identities (external_id) VALUES (NEW.id)
  ON CONFLICT (external_id) DO NOTHING;
  SELECT user_id INTO v_uuid FROM core.user_identities WHERE external_id = NEW.id;
  INSERT INTO core.users_meta (id, email)
  VALUES (v_uuid, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user') THEN
    DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
    CREATE TRIGGER trg_on_better_auth_user_created
    AFTER INSERT ON "user"
    FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();
  END IF;
END $$;
```

- [ ] **Step 6: Delete the two old files and rewrite the manifest** `packages/better-auth/sql-scripts.json` using variant-tagged entries:
```json
{
  "version": "1.0",
  "description": "better-auth adapter SQL — neutral-role wiring, auth impl (uuid|mapped), secrets, signup trigger",
  "scripts": [
    { "file": "sql/init/roles.sql" },
    { "file": "sql/init/secrets_pgcrypto_impl.sql" },
    { "variant": "uuid",   "file": "sql/init/auth_impl_uuid.sql" },
    { "variant": "mapped", "file": "sql/init/auth_impl_mapped.sql" },
    { "variant": "uuid",   "file": "sql/init/new_user_trigger_uuid.sql" },
    { "variant": "mapped", "file": "sql/init/new_user_trigger_mapped.sql" }
  ]
}
```

Run: `git rm packages/better-auth/sql/init/auth_better_auth_impl.sql packages/better-auth/sql/init/new_user_trigger.sql`

- [ ] **Step 7: Commit**

```bash
git add -A packages/better-auth/sql packages/better-auth/sql-scripts.json
git commit -m "feat(better-auth): role wiring + uuid/mapped auth impls and signup triggers"
```

### Task 5.2: Make the plain-Postgres load gate pass for BOTH better-auth modes

**Files:** none (verification + fix loop)

- [ ] **Step 1: Build and load uuid mode.**

Run:
```bash
node ./scripts/combine_files.js --adapter better-auth --better-auth-ids uuid
./scripts/test-plain-postgres-load.sh "$(ls -t SMTA-better-auth-*.sql | head -1)" smta-ba-uuid
```
Expected: `OK: … loaded cleanly`.

- [ ] **Step 2: Build and load mapped mode.**

Run:
```bash
node ./scripts/combine_files.js --adapter better-auth --better-auth-ids mapped
./scripts/test-plain-postgres-load.sh "$(ls -t SMTA-better-auth-*.sql | head -1)" smta-ba-mapped
```
Expected: `OK: … loaded cleanly`. If either fails, the psql error names the offending statement — fix in the relevant Phase-1/5 file, rebuild, rerun.

- [ ] **Step 3: Commit any fixes** with message `fix: resolve plain-postgres load errors for better-auth (<mode>)`. If no fixes were needed, skip.

---

## Phase 6 — Payload adapter

### Task 6.1: Wire payload to neutral roles + pgcrypto secrets; verify plain-PG load

**Files:**
- Create: `packages/payload/sql/init/roles.sql` (copy of better-auth `roles.sql`)
- Modify: `packages/payload/sql-scripts.json`

- [ ] **Step 1: Copy the roles wiring.**

Run: `cp packages/better-auth/sql/init/roles.sql packages/payload/sql/init/roles.sql`

- [ ] **Step 2: Update `packages/payload/sql-scripts.json`** to include the roles + secrets files alongside the existing auth impl:
```json
{
  "version": "1.0",
  "description": "Payload CMS adapter SQL — neutral-role wiring, session-variable auth, pgcrypto secrets",
  "scripts": [
    "sql/init/roles.sql",
    "sql/init/auth_payload_impl.sql",
    "sql/init/secrets_pgcrypto_impl.sql"
  ]
}
```

- [ ] **Step 3: Build and load payload on plain Postgres.**

Run:
```bash
node ./scripts/combine_files.js --adapter payload
./scripts/test-plain-postgres-load.sh "$(ls -t SMTA-payload-*.sql | head -1)" smta-payload
```
Expected: `OK: … loaded cleanly`.

- [ ] **Step 4: Commit**

```bash
git add -A packages/payload
git commit -m "feat(payload): neutral-role wiring + pgcrypto secrets; loads on plain postgres"
```

---

## Phase 7 — Functional tests on plain Postgres + adapter tests + CI

### Task 7.1: Adapter-aware test fixtures (plain-Postgres user source)

**Files:**
- Create: `tests/fixtures/00b_plain_pg_shim.sql`
- Modify: `scripts/run_tests.sh`

**Interfaces:**
- Produces: on plain Postgres, a `"user"` table + `app_user`/`app_admin` login roles + a `test_helpers.set_auth_user` that does NOT set a Supabase `role`. Selected by an env flag `SMTA_TARGET=plain|supabase` (default `supabase` to preserve current behavior).

- [ ] **Step 1: Create the shim** `tests/fixtures/00b_plain_pg_shim.sql` (loaded only when `SMTA_TARGET=plain`). It provides the pieces the Supabase harness assumes:
```sql
-- 00b_plain_pg_shim.sql
-- Purpose: Provide, on vanilla Postgres, the environment pieces the pgTap suite
-- assumed from Supabase: a Better-Auth-style "user" table and an auth-user setter
-- that uses app.current_user_id only (no GoTrue 'role').

CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT now(),
  "updatedAt" TIMESTAMPTZ DEFAULT now()
);

-- Override the helper so it does not reference Supabase roles.
CREATE OR REPLACE FUNCTION test_helpers.set_auth_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
END;
$$ LANGUAGE plpgsql;

-- create_test_user without auth.users / extensions.uuid_generate_v5.
CREATE OR REPLACE FUNCTION test_helpers.create_test_user(
  p_email TEXT, p_first_name TEXT DEFAULT NULL, p_last_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID := gen_random_uuid();
BEGIN
  INSERT INTO "user" (id, email, name) VALUES (v_user_id::text, p_email, p_first_name)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO core.users_meta (id, email, first_name, last_name)
  VALUES (v_user_id, p_email, p_first_name, p_last_name)
  ON CONFLICT (id) DO NOTHING;
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```
(Note: this is loaded AFTER `00_test_helpers.sql`, so its `CREATE OR REPLACE` wins. `create_test_user` here uses uuid mode; mapped-mode user-sync is covered in Task 7.3.)

- [ ] **Step 2: Branch fixture loading in `scripts/run_tests.sh`.** After the `00_test_helpers.sql` load line, add:
```bash
if [ "${SMTA_TARGET:-supabase}" = "plain" ]; then
  psql "$DB_URL" -q -f tests/fixtures/00b_plain_pg_shim.sql 2>> "$LOG_FILE"
  echo "✓ Loaded plain-postgres shim"
fi
```

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/00b_plain_pg_shim.sql scripts/run_tests.sh
git commit -m "test: plain-postgres fixture shim selectable via SMTA_TARGET"
```

### Task 7.2: Split the better-auth adapter test by id mode

**Files:**
- Modify: `tests/adapters/01_better_auth_adapter.sql`

**Interfaces:**
- Note: the current Section-2 `throws_ok` on a non-UUID id encodes uuid-mode behavior. Keep it as the **uuid-mode** test; mapped mode must NOT throw.

- [ ] **Step 1: Scope the existing test to uuid mode.** Rename the file purpose comment to "@smta/better-auth UUID mode". Leave the 8 assertions as-is (they validate uuid mode, including the `throws_ok` on `'not-a-uuid'`). No assertion changes.

- [ ] **Step 2: Commit**

```bash
git add tests/adapters/01_better_auth_adapter.sql
git commit -m "test: scope existing better-auth adapter test to uuid mode"
```

### Task 7.3: Add the mapped-mode adapter test

**Files:**
- Create: `tests/adapters/03_better_auth_mapped.sql`

- [ ] **Step 1: Write the mapped-mode test** (run against a DB deployed with `--better-auth-ids mapped`):
```sql
-- 03_better_auth_mapped.sql
-- Purpose: Verify @smta/better-auth MAPPED mode: arbitrary string ids map to UUIDs,
-- signup writes core.user_identities + core.users_meta, and get_current_user_id resolves.
BEGIN;
SELECT plan(4);

CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY, email TEXT NOT NULL, name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT now(), "updatedAt" TIMESTAMPTZ DEFAULT now()
);
DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
CREATE TRIGGER trg_on_better_auth_user_created
AFTER INSERT ON "user" FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();

-- A non-UUID (cuid-style) id must NOT throw in mapped mode.
SELECT lives_ok(
  $$INSERT INTO "user" (id, email) VALUES ('cuid_abc123', 'mapped@test.example.com')$$,
  'mapped mode: non-UUID id inserts without error'
);

-- A mapping row exists.
SELECT ok(
  EXISTS (SELECT 1 FROM core.user_identities WHERE external_id = 'cuid_abc123'),
  'mapped mode: user_identities row created for external id'
);

-- users_meta row exists with the minted UUID.
SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta um
    JOIN core.user_identities ui ON ui.user_id = um.id
    WHERE ui.external_id = 'cuid_abc123' AND um.email = 'mapped@test.example.com'
  ),
  'mapped mode: users_meta row minted and linked'
);

-- get_current_user_id resolves the external id from the session var to the UUID.
SELECT set_config('app.current_user_id', 'cuid_abc123', true);
SELECT is(
  core.get_current_user_id(),
  (SELECT user_id FROM core.user_identities WHERE external_id = 'cuid_abc123'),
  'mapped mode: get_current_user_id resolves external id to UUID'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Commit**

```bash
git add tests/adapters/03_better_auth_mapped.sql
git commit -m "test: mapped-mode user sync + id resolution for better-auth adapter"
```

### Task 7.4: Verify the full pgTap suite passes on plain Postgres (uuid mode)

**Files:** none (verification; fixes land in the file that fails)

- [ ] **Step 1: Deploy uuid-mode output + fixtures into a plain Postgres and run the suite.**

Run:
```bash
docker run -d --name smta-func -e POSTGRES_PASSWORD=postgres -p 55432:5432 postgres:18
sleep 5
docker exec smta-func psql -U postgres -c "CREATE DATABASE postgres2" || true
node ./scripts/combine_files.js --adapter better-auth --better-auth-ids uuid
PGPASSWORD=postgres psql -h localhost -p 55432 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f "$(ls -t SMTA-better-auth-*.sql | head -1)"
# pgtap must be available in the image; if not, document installing it in the CI image (Task 7.5).
SMTA_TARGET=plain DB_HOST=localhost DB_PORT=55432 DB_USER=postgres DB_PASSWORD=postgres DB_NAME=postgres ./scripts/run_tests.sh
docker rm -f smta-func
```
Expected: all pgTap tests pass. Where a test still assumes Supabase specifics (e.g. references `auth.users`, `service_role`, or `extensions.uuid_generate_v5`), fix that test/fixture to use the adapter-agnostic equivalent (`core.users_meta`, `app_admin`, `gen_random_uuid()`), keeping behavior identical on Supabase.

- [ ] **Step 2: Commit** any test/fixture fixes:

```bash
git add tests/
git commit -m "test: make pgTap suite pass on plain postgres (uuid mode)"
```

### Task 7.5: CI workflow — plain-Postgres load gate + functional suite

**Files:**
- Create: `.github/workflows/plain-postgres.yml`

- [ ] **Step 1: Write the workflow.** It builds all non-Supabase outputs and runs the load gate, then runs the functional suite for uuid mode.
```yaml
name: Plain PostgreSQL
on:
  pull_request:
  push:
    branches: [main, master]
jobs:
  load-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci || npm install
      - name: Build adapter outputs
        run: |
          node ./scripts/combine_files.js --adapter better-auth --better-auth-ids uuid
          mv "$(ls -t SMTA-better-auth-*.sql | head -1)" /tmp/ba-uuid.sql
          node ./scripts/combine_files.js --adapter better-auth --better-auth-ids mapped
          mv "$(ls -t SMTA-better-auth-*.sql | head -1)" /tmp/ba-mapped.sql
          node ./scripts/combine_files.js --adapter payload
          mv "$(ls -t SMTA-payload-*.sql | head -1)" /tmp/payload.sql
      - name: Load gate (vanilla postgres:18)
        run: |
          ./scripts/test-plain-postgres-load.sh /tmp/ba-uuid.sql  smta-ci-ba-uuid
          ./scripts/test-plain-postgres-load.sh /tmp/ba-mapped.sql smta-ci-ba-mapped
          ./scripts/test-plain-postgres-load.sh /tmp/payload.sql   smta-ci-payload
  functional:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18
        env: { POSTGRES_PASSWORD: postgres }
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U postgres" --health-interval 5s
          --health-timeout 5s --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Install pgTap + pg_prove
        run: |
          sudo apt-get update
          sudo apt-get install -y postgresql-16-pgtap libtap-parser-sourcehandler-pgtap-perl postgresql-client
      - run: npm ci || npm install
      - name: Deploy better-auth (uuid) schema
        env: { PGPASSWORD: postgres }
        run: |
          node ./scripts/combine_files.js --adapter better-auth --better-auth-ids uuid
          psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -f "$(ls -t SMTA-better-auth-*.sql | head -1)"
      - name: Run pgTap suite (plain target)
        env:
          SMTA_TARGET: plain
          DB_HOST: localhost
          DB_PORT: '5432'
          DB_USER: postgres
          DB_PASSWORD: postgres
          DB_NAME: postgres
        run: ./scripts/run_tests.sh
```

- [ ] **Step 2: Validate the workflow YAML locally.**

Run: `node -e "require('js-yaml')" 2>/dev/null && npx --yes js-yaml .github/workflows/plain-postgres.yml >/dev/null && echo OK || python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/plain-postgres.yml')); print('OK')"`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/plain-postgres.yml
git commit -m "ci: plain-postgres load gate + functional pgTap suite"
```

---

## Phase 8 — Documentation

### Task 8.1: Update adapter READMEs

**Files:**
- Modify: `packages/better-auth/README.md`
- Modify: `packages/payload/README.md`
- Modify: `packages/supabase/README.md`

- [ ] **Step 1: Better-auth README.** Document: (a) the runtime backend must connect as a role that inherits `app_user` (NOT BYPASSRLS) or RLS is void; migrations as `app_admin`; (b) the `--better-auth-ids uuid|mapped` decision, with `uuid` recommended for performance and the aside that setting Better-Auth `advanced.database.generateId` to emit UUIDs is ideal, while `mapped` needs zero Better-Auth config; (c) `app.secrets_key` GUC required for secrets. Update the existing `fk_users_meta_auth_users` paragraph to note it is dropped by whichever signup-trigger variant runs.

- [ ] **Step 2: Payload README.** Same role-model + `app.secrets_key` notes.

- [ ] **Step 3: Supabase README.** Note core is now adapter-agnostic; the supabase adapter maps `authenticated`→`app_user`, `service_role`→`app_admin`, restores `auth.users` FKs and the signup trigger, owns the `pg_graphql` disable, and provides Vault `read_secret_impl`. Behavior is unchanged.

- [ ] **Step 4: Commit**

```bash
git add packages/*/README.md
git commit -m "docs: adapter role model, better-auth id modes, pgcrypto secrets key"
```

---

## Self-Review (completed during planning)

**Spec coverage:** Every spec section maps to a task — §1 roles → 1.1; §2 de-supabase DDL → 1.2–1.8; §3 adapter responsibilities → 2.1–2.3 (supabase), 5.x (better-auth), 6.1 (payload); §4 identity flag/modes → 4.1, 5.1–5.2; §5 pgcrypto secrets → 1.9 (interface), 3.1–3.2; §6 CI/verification → 0.1, 5.2, 6.1, 7.1–7.5; findings A1–C11 all land in Phase 1/2; docs → 8.1.

**Placeholder scan:** No TBD/TODO; every code step shows full SQL/JS/YAML; commands have expected output.

**Type/name consistency:** `app_user`/`app_admin`, `app.current_user_id`, `app.secrets_key`, `core.user_identities(external_id, user_id)`, `core.handle_new_better_auth_user`, `--better-auth-ids uuid|mapped`, and the variant-tagged manifest shape are used identically across Tasks 1.1, 3.1, 4.1, 5.1, 7.x.

**Known follow-ups (not blocking):** the mapped-mode functional pgTap run beyond the dedicated Task 7.3 test is deferred; uuid mode is the CI functional default. If broad mapped-mode functional coverage is later wanted, it is a clean add-on plan.
