# Package Restructure & sql/ Elimination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate all adapter-agnostic SQL into `@smta/core`, shrink each adapter package to only its truly adapter-specific SQL, eliminate the duplicate `sql/` tree, and update `combine_files.js` to assemble deployment scripts from packages with an `--adapter` flag.

**Architecture:** Three tasks move files (no SQL logic changes). Three tasks update manifests and tooling. A final task verifies the build produces valid output, runs the full test suite, then deletes the legacy `sql/` tree and `scripts/sql-scripts.json`.

**Tech Stack:** PostgreSQL, pgTap, Node.js (combine_files.js), pnpm workspaces

---

## File Map

### Directories moving INTO `packages/core/sql/`
| From | To |
|---|---|
| `packages/supabase/sql/platform/` | `packages/core/sql/platform/` |
| `packages/supabase/sql/public/` | `packages/core/sql/public/` |

### Files moving OUT OF `packages/core/sql/init/`
| From | To |
|---|---|
| `packages/core/sql/init/auth_supabase_impl.sql` | `packages/supabase/sql/init/auth_supabase_impl.sql` |
| `packages/core/sql/init/secrets_supabase_impl.sql` | `packages/supabase/sql/init/secrets_supabase_impl.sql` |

### File renamed in `packages/payload/`
| From | To |
|---|---|
| `packages/payload/sql/auth/get_current_user_id.sql` | `packages/payload/sql/init/auth_payload_impl.sql` |

### Manifests rewritten
- `packages/core/sql-scripts.json` — expanded to include platform + public
- `packages/supabase/sql-scripts.json` — reduced to 3 entries
- `packages/payload/sql-scripts.json` — reduced to 1 entry

### Tooling updated
- `scripts/combine_files.js` — rewritten with `--adapter` flag
- `package.json` — build scripts updated

### Deleted at end
- `sql/` — entire directory tree
- `scripts/sql-scripts.json`

---

## Task 1: Move platform and public SQL into @smta/core

**Files:**
- Move: `packages/supabase/sql/platform/` → `packages/core/sql/platform/`
- Move: `packages/supabase/sql/public/` → `packages/core/sql/public/`

- [ ] **Step 1: Move the platform directory**

```bash
mv packages/supabase/sql/platform packages/core/sql/platform
```

- [ ] **Step 2: Move the public directory**

```bash
mv packages/supabase/sql/public packages/core/sql/public
```

- [ ] **Step 3: Verify the destination structure**

```bash
find packages/core/sql/platform packages/core/sql/public -name "*.sql" | sort
```

Expected output — 32 files total:
```
packages/core/sql/platform/functions/audit.sql
packages/core/sql/platform/functions/billing.sql
packages/core/sql/platform/functions/events.sql
packages/core/sql/platform/functions/feature_flags.sql
packages/core/sql/platform/functions/log_action.sql
packages/core/sql/platform/functions/organizations.sql
packages/core/sql/platform/functions/overrides.sql
packages/core/sql/platform/functions/products.sql
packages/core/sql/platform/functions/settings.sql
packages/core/sql/platform/functions/users.sql
packages/core/sql/platform/rls/lockdown.sql
packages/core/sql/platform/tables/action_logs.sql
packages/core/sql/platform/tables/billing_customers.sql
packages/core/sql/platform/tables/billing_subscriptions.sql
packages/core/sql/platform/tables/feature_flags.sql
packages/core/sql/platform/tables/grants.sql
packages/core/sql/platform/tables/organizations.sql
packages/core/sql/platform/tables/roles.sql
packages/core/sql/platform/tables/settings.sql
packages/core/sql/platform/tables/subscription_overrides.sql
packages/core/sql/platform/tables/subscription_products.sql
packages/core/sql/platform/tables/system_events.sql
packages/core/sql/platform/tables/tenant_secrets.sql
packages/core/sql/platform/tables/users.sql
packages/core/sql/public/functions/audit.sql
packages/core/sql/public/functions/files.sql
packages/core/sql/public/functions/invitations.sql
packages/core/sql/public/functions/organizations.sql
packages/core/sql/public/functions/products.sql
packages/core/sql/public/functions/secrets.sql
packages/core/sql/public/functions/units.sql
packages/core/sql/public/functions/user_profile.sql
```

- [ ] **Step 4: Verify supabase package no longer has platform or public**

```bash
ls packages/supabase/sql/
```

Expected: only `constraints.sql` (no `platform/` or `public/`)

- [ ] **Step 5: Commit**

```bash
git add packages/core/sql/platform packages/core/sql/public packages/supabase/sql/
git commit -m "refactor: move platform and public SQL from @smta/supabase into @smta/core"
```

---

## Task 2: Relocate adapter-specific auth and secrets SQL

**Files:**
- Move: `packages/core/sql/init/auth_supabase_impl.sql` → `packages/supabase/sql/init/auth_supabase_impl.sql`
- Move: `packages/core/sql/init/secrets_supabase_impl.sql` → `packages/supabase/sql/init/secrets_supabase_impl.sql`
- Move+Rename: `packages/payload/sql/auth/get_current_user_id.sql` → `packages/payload/sql/init/auth_payload_impl.sql`

- [ ] **Step 1: Create init directories in each adapter package**

```bash
mkdir -p packages/supabase/sql/init
mkdir -p packages/payload/sql/init
```

- [ ] **Step 2: Move Supabase auth and secrets impls out of core**

```bash
mv packages/core/sql/init/auth_supabase_impl.sql packages/supabase/sql/init/auth_supabase_impl.sql
mv packages/core/sql/init/secrets_supabase_impl.sql packages/supabase/sql/init/secrets_supabase_impl.sql
```

- [ ] **Step 3: Move and rename Payload auth impl**

```bash
mv packages/payload/sql/auth/get_current_user_id.sql packages/payload/sql/init/auth_payload_impl.sql
rmdir packages/payload/sql/auth
```

- [ ] **Step 4: Verify core init only contains adapter-agnostic files**

```bash
ls packages/core/sql/init/
```

Expected:
```
auth_interface.sql
schemas.sql
secrets_interface.sql
```

- [ ] **Step 5: Verify supabase init contains both impls**

```bash
ls packages/supabase/sql/init/
```

Expected:
```
auth_supabase_impl.sql
secrets_supabase_impl.sql
```

- [ ] **Step 6: Verify payload init contains the auth impl**

```bash
ls packages/payload/sql/init/
```

Expected:
```
auth_payload_impl.sql
```

- [ ] **Step 7: Commit**

```bash
git add packages/core/sql/init/ packages/supabase/sql/init/ packages/payload/sql/
git commit -m "refactor: relocate auth/secrets impls from @smta/core to adapter packages"
```

---

## Task 3: Update all three sql-scripts.json manifests

**Files:**
- Modify: `packages/core/sql-scripts.json`
- Modify: `packages/supabase/sql-scripts.json`
- Modify: `packages/payload/sql-scripts.json`

- [ ] **Step 1: Rewrite packages/core/sql-scripts.json**

Replace the entire file with:

```json
{
  "version": "1.0",
  "description": "Core package SQL execution order — adapter-agnostic SMTA schema",
  "scripts": [
    "sql/init/schemas.sql",
    "sql/init/auth_interface.sql",
    "sql/init/secrets_interface.sql",
    "sql/utils/functions.sql",
    "sql/platform/tables/roles.sql",
    "sql/platform/tables/users.sql",
    "sql/platform/tables/organizations.sql",
    "sql/platform/tables/action_logs.sql",
    "sql/platform/tables/settings.sql",
    "sql/platform/tables/subscription_overrides.sql",
    "sql/platform/tables/feature_flags.sql",
    "sql/platform/tables/system_events.sql",
    "sql/tables/organizations.sql",
    "sql/tables/units.sql",
    "sql/tables/roles.sql",
    "sql/tables/memberships.sql",
    "sql/tables/users_meta.sql",
    "sql/tables/organization_files.sql",
    "sql/tables/organizations_meta.sql",
    "sql/tables/audit_logs.sql",
    "sql/tables/invitations.sql",
    "sql/tables/grants.sql",
    "sql/triggers/new_user.sql",
    "sql/triggers/new_organization.sql",
    "sql/triggers/new_unit.sql",
    "sql/triggers/protect_super_admin.sql",
    "sql/platform/tables/tenant_secrets.sql",
    "sql/platform/tables/billing_customers.sql",
    "sql/platform/tables/billing_subscriptions.sql",
    "sql/platform/tables/subscription_products.sql",
    "sql/platform/tables/grants.sql",
    "sql/rls/helpers.sql",
    "sql/rls/policies.sql",
    "sql/rls/invitations.sql",
    "sql/platform/rls/lockdown.sql",
    "sql/functions/log_audit.sql",
    "sql/functions/secrets.sql",
    "sql/functions/invitations.sql",
    "sql/public/functions/user_profile.sql",
    "sql/public/functions/organizations.sql",
    "sql/public/functions/units.sql",
    "sql/public/functions/files.sql",
    "sql/public/functions/audit.sql",
    "sql/public/functions/secrets.sql",
    "sql/public/functions/invitations.sql",
    "sql/platform/functions/log_action.sql",
    "sql/platform/functions/users.sql",
    "sql/platform/functions/organizations.sql",
    "sql/platform/functions/overrides.sql",
    "sql/platform/functions/feature_flags.sql",
    "sql/platform/functions/events.sql",
    "sql/platform/functions/audit.sql",
    "sql/platform/functions/settings.sql",
    "sql/platform/functions/billing.sql",
    "sql/platform/functions/products.sql",
    "sql/public/functions/products.sql"
  ]
}
```

Note: `public/functions/products.sql` is last because it wraps `platform.get_subscription_products()` which must exist first.

- [ ] **Step 2: Rewrite packages/supabase/sql-scripts.json**

Replace the entire file with:

```json
{
  "version": "1.0",
  "description": "Supabase adapter SQL — auth/secrets implementations and auth.users FK constraints",
  "scripts": [
    "sql/init/auth_supabase_impl.sql",
    "sql/init/secrets_supabase_impl.sql",
    "sql/constraints.sql"
  ]
}
```

- [ ] **Step 3: Rewrite packages/payload/sql-scripts.json**

Replace the entire file with:

```json
{
  "version": "1.0",
  "description": "Payload CMS adapter SQL — session-variable auth implementation",
  "scripts": [
    "sql/init/auth_payload_impl.sql"
  ]
}
```

- [ ] **Step 4: Verify all three files are valid JSON**

```bash
node -e "require('./packages/core/sql-scripts.json')" && echo "core OK"
node -e "require('./packages/supabase/sql-scripts.json')" && echo "supabase OK"
node -e "require('./packages/payload/sql-scripts.json')" && echo "payload OK"
```

Expected:
```
core OK
supabase OK
payload OK
```

- [ ] **Step 5: Commit**

```bash
git add packages/core/sql-scripts.json packages/supabase/sql-scripts.json packages/payload/sql-scripts.json
git commit -m "refactor: update sql-scripts.json manifests to reflect new package boundaries"
```

---

## Task 4: Rewrite scripts/combine_files.js with --adapter flag

**Files:**
- Modify: `scripts/combine_files.js`

- [ ] **Step 1: Replace scripts/combine_files.js with the new version**

```javascript
const fs = require('node:fs/promises')
const path = require('node:path')

const ADAPTERS = ['supabase', 'payload']
const ROOT = path.join(__dirname, '..')

async function readPackageScripts(packageDir) {
  const manifestPath = path.join(packageDir, 'sql-scripts.json')
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
  return manifest.scripts.map(file => path.join(packageDir, file))
}

async function combineFiles() {
  const adapterIdx = process.argv.indexOf('--adapter')
  const adapterName = adapterIdx !== -1 ? process.argv[adapterIdx + 1] : 'supabase'

  if (!ADAPTERS.includes(adapterName)) {
    console.error(`Unknown adapter "${adapterName}". Valid adapters: ${ADAPTERS.join(', ')}`)
    process.exit(1)
  }

  const coreDir = path.join(ROOT, 'packages', 'core')
  const adapterDir = path.join(ROOT, 'packages', adapterName)

  const corePaths = await readPackageScripts(coreDir)
  const adapterPaths = await readPackageScripts(adapterDir)
  const allPaths = [...corePaths, ...adapterPaths]

  const parts = await Promise.all(allPaths.map(f => fs.readFile(f, 'utf8')))
  const combined = parts.join('\n\n-- =============== NEW FILE =================\n\n')

  if (combined.length > 0) {
    const outputPath = path.join(ROOT, 'output', `SMTA-${adapterName}-${Date.now()}.sql`)
    await fs.writeFile(outputPath, combined, 'utf8')
    console.log(`${allPaths.length} files combined into ${outputPath}`)
  } else {
    console.error('Something went wrong — no file created.')
    process.exit(1)
  }
}

combineFiles()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/combine_files.js
git commit -m "refactor: rewrite combine_files.js to assemble from packages with --adapter flag"
```

---

## Task 5: Update root package.json build scripts

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Update the scripts section in package.json**

Replace:
```json
"scripts": {
  "test": "./scripts/run_tests.sh",
  "build": "node ./scripts/combine_files.js"
},
```

With:
```json
"scripts": {
  "test": "./scripts/run_tests.sh",
  "build:supabase": "node ./scripts/combine_files.js --adapter supabase",
  "build:payload": "node ./scripts/combine_files.js --adapter payload",
  "build": "npm run build:supabase && npm run build:payload"
},
```

- [ ] **Step 2: Commit**

```bash
git add package.json
git commit -m "refactor: add build:supabase and build:payload scripts"
```

---

## Task 6: Verify build, run tests, delete legacy sql/ tree

**Files:**
- Delete: `sql/` (entire directory)
- Delete: `scripts/sql-scripts.json`

- [ ] **Step 1: Verify supabase build produces output**

```bash
node scripts/combine_files.js --adapter supabase
```

Expected (56 core files + 3 supabase files = 59 total):
```
59 files combined into .../output/SMTA-supabase-<timestamp>.sql
```

- [ ] **Step 2: Verify payload build produces output**

```bash
node scripts/combine_files.js --adapter payload
```

Expected (56 core files + 1 payload file = 57 total):
```
57 files combined into .../output/SMTA-payload-<timestamp>.sql
```

- [ ] **Step 3: Spot-check the supabase output**

Verify the combined file starts with schemas, ends with constraints, and contains no blank sections:

```bash
head -5 output/SMTA-supabase-*.sql | tail -5
grep -c "NEW FILE" output/SMTA-supabase-*.sql
tail -30 output/SMTA-supabase-*.sql
```

Expected: `grep` returns `58` (one separator between each of the 59 files). `tail` shows the constraints SQL.

- [ ] **Step 4: Deploy the supabase build to the test database**

Follow the existing deployment procedure for your local database (apply the generated SQL file against the test PostgreSQL instance). The exact command depends on your local setup — typically:

```bash
psql "$DB_URL" -f output/SMTA-supabase-<timestamp>.sql
```

where `DB_URL` is your local Supabase connection string from `.env`.

- [ ] **Step 5: Run the full test suite**

```bash
./scripts/run_tests.sh
```

Expected:
```
Files=35, Tests=449, ...
Result: PASS
```

If any tests fail, do not proceed to Step 6. Diagnose against the output SQL — the file moves should not have changed any SQL logic, so a failure indicates a manifest ordering error in Task 3.

- [ ] **Step 6: Delete the legacy sql/ directory and scripts/sql-scripts.json**

```bash
rm -rf sql/
rm scripts/sql-scripts.json
```

- [ ] **Step 7: Verify the build still works without sql/**

```bash
node scripts/combine_files.js --adapter supabase && node scripts/combine_files.js --adapter payload
```

Both should succeed. (combine_files.js no longer references sql/ — it reads from packages.)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: delete legacy sql/ tree and scripts/sql-scripts.json — packages are now the single source of truth"
```

---

## Verification Checklist

After all tasks complete:

- [ ] `packages/core/sql/` contains `platform/`, `public/`, `tables/`, `triggers/`, `functions/`, `rls/`, `init/`, `utils/`, `app/`
- [ ] `packages/core/sql/init/` contains only `schemas.sql`, `auth_interface.sql`, `secrets_interface.sql`
- [ ] `packages/supabase/sql/` contains only `init/` and `constraints.sql`
- [ ] `packages/payload/sql/` contains only `init/`
- [ ] `sql/` does not exist
- [ ] `scripts/sql-scripts.json` does not exist
- [ ] `node scripts/combine_files.js --adapter supabase` → success
- [ ] `node scripts/combine_files.js --adapter payload` → success
- [ ] `./scripts/run_tests.sh` → 449 tests passing
