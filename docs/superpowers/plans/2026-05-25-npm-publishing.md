# npm Publishing Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish all 6 SMTA packages to npm under `@smta/*` with fixed (lock-step) versioning via Changesets and a GitHub Actions publish workflow.

**Architecture:** All packages share a single version number (Changesets `fixed` mode) so the SQL deployed and the TypeScript packages installed are always in sync. A new `@smta/cli` package wraps the existing `combine_files.js` script to give end users a versioned, npx-runnable deployment tool. SQL-only packages publish their raw files; TypeScript packages publish compiled `dist/`.

**Tech Stack:** pnpm workspaces, @changesets/cli, GitHub Actions (`changesets/action@v1`), Node.js (no build step for CLI or SQL packages), TypeScript (billing, schemas, payload).

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `packages/cli/package.json` | CLI package manifest |
| Create | `packages/cli/deploy.js` | Deploy script (adapted from `scripts/combine_files.js`) |
| Modify | `packages/core/package.json` | ~~Remove `private`, add `publishConfig`~~ ✅ — add `files` |
| Modify | `packages/supabase/package.json` | ~~Remove `private`, add `publishConfig`~~ ✅ — add `files` |
| Modify | `packages/payload/package.json` | ~~Remove `private`, add `publishConfig`~~ ✅ — add `files` |
| Modify | `packages/billing/package.json` | ~~Remove `private`, add `publishConfig`~~ ✅ — add `files` |
| Modify | `packages/schemas/package.json` | ~~Remove `private`, add `publishConfig`~~ ✅ — add `files` |
| Modify | `package.json` (root) | Add `release` script |
| Create | `.changeset/config.json` | Changesets config with `fixed` mode (via `changeset init` then edit) |
| Create | `.github/workflows/changesets.yml` | CI: open version PR or publish on merge to `main` |

---

### Task 1: Create `packages/cli/deploy.js`

The existing `scripts/combine_files.js` is hardcoded to read from `packages/` relative to the repo root. The CLI version must resolve packages via `require.resolve` so it works both in the local workspace (pnpm links `@smta/core` etc.) and when installed from npm (reads from `node_modules/@smta/`). Output goes to `process.cwd()` since the user runs it from their own project.

**Files:**
- Create: `packages/cli/deploy.js`

- [ ] **Step 1: Create the deploy script**

```javascript
#!/usr/bin/env node
'use strict'

const fs = require('node:fs/promises')
const path = require('node:path')

const ADAPTERS = ['supabase', 'payload']

function resolvePackageDir(packageName) {
  const manifestPath = require.resolve(`${packageName}/package.json`)
  return path.dirname(manifestPath)
}

async function readPackageScripts(packageDir) {
  const manifestPath = path.join(packageDir, 'sql-scripts.json')
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
  return manifest.scripts.map(file => path.join(packageDir, file))
}

async function deploy() {
  const adapterIdx = process.argv.indexOf('--adapter')
  const adapterName = adapterIdx !== -1 ? process.argv[adapterIdx + 1] : 'supabase'

  if (!ADAPTERS.includes(adapterName)) {
    console.error(`Unknown adapter "${adapterName}". Valid adapters: ${ADAPTERS.join(', ')}`)
    process.exit(1)
  }

  const coreDir = resolvePackageDir('@smta/core')
  const adapterDir = resolvePackageDir(`@smta/${adapterName}`)

  const corePaths = await readPackageScripts(coreDir)
  const adapterPaths = await readPackageScripts(adapterDir)
  const allPaths = [...corePaths, ...adapterPaths]

  const parts = await Promise.all(allPaths.map(f => fs.readFile(f, 'utf8')))
  const combined = parts.join('\n\n-- =============== NEW FILE =================\n\n')

  if (combined.length === 0) {
    console.error('Something went wrong — no content to write.')
    process.exit(1)
  }

  const outputPath = path.join(process.cwd(), `SMTA-${adapterName}-${Date.now()}.sql`)
  await fs.writeFile(outputPath, combined, 'utf8')
  console.log(`${allPaths.length} files combined into ${outputPath}`)
}

deploy()
```

- [ ] **Step 2: Verify it runs correctly from the repo root (workspace resolves `@smta/core` via pnpm)**

```bash
node packages/cli/deploy.js --adapter supabase
```

Expected output: `59 files combined into /home/jeff/Documents/Development/saasdb/SMTA-supabase-<timestamp>.sql`

- [ ] **Step 3: Verify the payload adapter also works**

```bash
node packages/cli/deploy.js --adapter payload
```

Expected output: `57 files combined into /home/jeff/Documents/Development/saasdb/SMTA-payload-<timestamp>.sql`

- [ ] **Step 4: Clean up output files**

```bash
rm /home/jeff/Documents/Development/saasdb/SMTA-supabase-*.sql
rm /home/jeff/Documents/Development/saasdb/SMTA-payload-*.sql
```

- [ ] **Step 5: Commit**

```bash
git add packages/cli/deploy.js
git commit -m "feat: add @smta/cli deploy script"
```

---

### Task 2: Create `packages/cli/package.json`

**Files:**
- Create: `packages/cli/package.json`

- [ ] **Step 1: Write the package manifest**

```json
{
  "name": "@smta/cli",
  "version": "0.1.0",
  "description": "SMTA deployment CLI — combines and outputs a versioned SQL deployment script",
  "bin": {
    "smta": "./deploy.js"
  },
  "files": [
    "deploy.js"
  ],
  "peerDependencies": {
    "@smta/core": "*",
    "@smta/supabase": "*",
    "@smta/payload": "*"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 2: Run `pnpm install` from repo root to register the new workspace package**

```bash
pnpm install
```

Expected: no errors, `@smta/cli` appears in the workspace.

- [ ] **Step 3: Confirm workspace link resolves**

```bash
pnpm list --filter @smta/cli
```

Expected: `@smta/cli 0.1.0` listed.

- [ ] **Step 4: Commit**

```bash
git add packages/cli/package.json pnpm-lock.yaml
git commit -m "feat: add @smta/cli package manifest"
```

---

### Task 3: Add `files` field to all package manifests

`private: true` has been removed and `publishConfig` added to all packages already. The only remaining change is adding `files` so npm doesn't ship `src/`, `tsconfig.json`, etc. alongside the published output.

**Files:**
- Modify: `packages/core/package.json`
- Modify: `packages/supabase/package.json`
- Modify: `packages/payload/package.json`
- Modify: `packages/billing/package.json`
- Modify: `packages/schemas/package.json`

- [ ] **Step 1: Add `files` to `packages/core/package.json`**

```json
{
  "name": "@smta/core",
  "version": "0.1.0",
  "description": "SMTA core PostgreSQL schema — tenant isolation via RLS, tables, and functions",
  "files": [
    "sql",
    "sql-scripts.json"
  ],
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 2: Add `files` to `packages/supabase/package.json`**

```json
{
  "name": "@smta/supabase",
  "version": "0.1.0",
  "description": "SMTA Supabase adapter — auth.uid(), Vault, PostgREST config, platform schema",
  "files": [
    "sql",
    "sql-scripts.json"
  ],
  "dependencies": {
    "@smta/core": "workspace:*"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 3: Add `files` to `packages/payload/package.json`**

```json
{
  "name": "@smta/payload",
  "version": "0.1.0",
  "description": "SMTA Payload CMS adapter — auth context injection middleware",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist",
    "sql",
    "sql-scripts.json"
  ],
  "scripts": {
    "build": "tsc --build",
    "lint": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 4: Add `files` to `packages/billing/package.json`**

Note: preserve the existing `"license": "MIT"` field.

```json
{
  "name": "@smta/billing",
  "version": "0.1.0",
  "license": "MIT",
  "description": "SMTA billing provider abstraction — Stripe and Lemon Squeezy",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc --build",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "stripe": "^17.0.0",
    "@lemonsqueezy/lemonsqueezy.js": "^4.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/pg": "^8.0.0",
    "pg": "^8.0.0"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 5: Add `files` to `packages/schemas/package.json`**

```json
{
  "name": "@smta/schemas",
  "version": "0.1.0",
  "description": "Zod schemas for SMTA public.* RPC function contracts",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc --build",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "zod": "^4.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

- [ ] **Step 6: Verify TypeScript packages still build**

```bash
pnpm --filter @smta/payload build
pnpm --filter @smta/billing build
pnpm --filter @smta/schemas build
```

Expected: each exits 0 with no errors.

- [ ] **Step 7: Commit**

```bash
git add packages/core/package.json packages/supabase/package.json packages/payload/package.json packages/billing/package.json packages/schemas/package.json
git commit -m "feat: add files field to all @smta package manifests"
```

> **Note:** Task 4 from the original plan has been absorbed here — `private` removal and `publishConfig` were already completed.

---

### Task 5: Install and configure Changesets

**Files:**
- Modify: `package.json` (root) — add `release` script
- Create: `.changeset/config.json` — via `changeset init`, then edited

- [ ] **Step 1: Install `@changesets/cli` as a root dev dependency**

```bash
pnpm add --save-dev -w @changesets/cli
```

- [ ] **Step 2: Initialize Changesets**

```bash
pnpm changeset init
```

Expected: creates `.changeset/config.json` and `.changeset/README.md`.

- [ ] **Step 3: Replace `.changeset/config.json` with the fixed-mode config**

```json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [
    [
      "@smta/core",
      "@smta/supabase",
      "@smta/payload",
      "@smta/billing",
      "@smta/schemas",
      "@smta/cli"
    ]
  ],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

- [ ] **Step 4: Add `release` script to root `package.json`**

The current root `package.json` `scripts` block:
```json
"scripts": {
  "test": "./scripts/run_tests.sh",
  "build:supabase": "node ./scripts/combine_files.js --adapter supabase",
  "build:payload": "node ./scripts/combine_files.js --adapter payload",
  "build": "npm run build:supabase && npm run build:payload",
  "build:docs": "pnpm --filter @smta/docs build"
}
```

Add `release` to get:
```json
"scripts": {
  "test": "./scripts/run_tests.sh",
  "build:supabase": "node ./scripts/combine_files.js --adapter supabase",
  "build:payload": "node ./scripts/combine_files.js --adapter payload",
  "build": "npm run build:supabase && npm run build:payload",
  "build:docs": "pnpm --filter @smta/docs build",
  "release": "changeset publish"
}
```

- [ ] **Step 5: Verify `changeset status` runs cleanly**

```bash
pnpm changeset status
```

Expected: `No changesets present` or similar — no errors.

- [ ] **Step 6: Commit**

```bash
git add .changeset/config.json .changeset/README.md package.json pnpm-lock.yaml
git commit -m "feat: set up Changesets with fixed versioning for all @smta packages"
```

---

### Task 6: Create GitHub Actions publish workflow

This workflow runs on every push to `main`. If pending changesets exist, it opens or updates a "Version Packages" PR. When that PR is merged (no more pending changesets), it builds all TypeScript packages and publishes everything to npm.

**Files:**
- Create: `.github/workflows/changesets.yml`

- [ ] **Step 1: Create the `.github/workflows/` directory and workflow file**

```yaml
name: Changesets

on:
  push:
    branches:
      - main

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 10

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: "https://registry.npmjs.org"

      - run: pnpm install

      - name: Build TypeScript packages
        run: |
          pnpm --filter @smta/payload build
          pnpm --filter @smta/billing build
          pnpm --filter @smta/schemas build

      - name: Create Release PR or Publish
        uses: changesets/action@v1
        with:
          publish: pnpm run release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/changesets.yml
git commit -m "feat: add GitHub Actions Changesets publish workflow"
```

---

## Post-Plan: First Publish Checklist (manual, one-time)

These steps cannot be automated — they require accounts and tokens you create externally. Complete them before the workflow can publish.

1. ~~**Create `@smta` npm org**~~ ✅ — already exists at npmjs.com as `smta`
2. **Create granular npm token** — npmjs.com > Access Tokens > Generate New Token > Granular Access Token > Read & Write, scoped to `@smta/*`
3. **Add token to GitHub** — GitHub org `saas-multi-tenant-architecture` > Settings > Secrets > Actions > new secret named `NPM_TOKEN`
4. **First publish (manual)** — run `pnpm changeset publish` locally with npm credentials. After this, the Actions workflow takes over.

---

## Self-Review

**Spec coverage:**
- ✅ `packages/cli/` created and wraps `combine_files.js` with `require.resolve`
- ✅ All 5 existing packages updated (`private` removed, `files`, `publishConfig`)
- ✅ `@smta/cli` added to fixed group
- ✅ Changesets installed with `fixed` mode covering all 6 packages
- ✅ Root `release` script added
- ✅ GitHub Actions workflow with pnpm, build step, and `changesets/action`

**Placeholder scan:** No TBDs, TODOs, or vague steps found.

**Type consistency:** No TypeScript types defined across tasks — n/a.
