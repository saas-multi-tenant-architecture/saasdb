# @smta/better-auth Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `@smta/better-auth` — a new adapter package that wires better-auth's session identity into SMTA's RLS enforcement and exposes SMTA's tenant management functions through a better-auth plugin.

**Architecture:** A new `packages/better-auth/` package follows the exact conventions of `@smta/payload`. SQL layer overrides `core.get_current_user_id()` to read from the `app.current_user_id` session variable (same as Payload). A TypeScript `withSMTA()` wrapper sets that variable per-transaction. A better-auth plugin wraps SMTA's `public.*` functions as `auth.api.*` endpoints and adds `activeOrgId` to the session.

**Tech Stack:** PostgreSQL (pgTap tests), TypeScript, `pg` (node-postgres), better-auth plugin API

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `packages/better-auth/package.json` | npm package definition |
| Create | `packages/better-auth/tsconfig.json` | TypeScript compiler config |
| Create | `packages/better-auth/sql-scripts.json` | SQL execution order for deploy script |
| Create | `packages/better-auth/sql/init/auth_better_auth_impl.sql` | `core.get_current_user_id()` implementation |
| Create | `packages/better-auth/sql/init/new_user_trigger.sql` | Trigger on better-auth's `user` table |
| Create | `packages/better-auth/src/middleware/inject-user-context.ts` | `withSMTA()`, `injectUserContext()`, `clearUserContext()` |
| Create | `packages/better-auth/src/plugin/session.ts` | `activeOrgId` session types |
| Create | `packages/better-auth/src/plugin/endpoints.ts` | SMTA `public.*` wrapped as `auth.api.*` |
| Create | `packages/better-auth/src/plugin/index.ts` | Plugin composition |
| Create | `packages/better-auth/src/index.ts` | Package exports |
| Create | `packages/better-auth/README.md` | Usage documentation |
| Create | `tests/adapters/01_better_auth_adapter.sql` | pgTap tests for the adapter |
| Modify | `pnpm-workspace.yaml` | Add `packages/better-auth` |
| Modify | `scripts/combine_files.js` | Add `better-auth` to ADAPTERS list |
| Modify | `package.json` | Add `build:better-auth` script |

**Note:** `scripts/run_tests.sh` is NOT modified. The adapter test file is run standalone against a better-auth-deployed database (see Task 3 and README).

---

### Task 1: Package Scaffolding

**Files:**
- Create: `packages/better-auth/package.json`
- Create: `packages/better-auth/tsconfig.json`
- Create: `packages/better-auth/sql-scripts.json`
- Modify: `pnpm-workspace.yaml`

- [ ] **Step 1: Create the package directory and `package.json`**

```bash
mkdir -p packages/better-auth/sql/init packages/better-auth/src/middleware packages/better-auth/src/plugin
```

Create `packages/better-auth/package.json`:

```json
{
  "name": "@smta/better-auth",
  "version": "0.1.0",
  "description": "SMTA better-auth adapter — session-variable auth implementation and better-auth plugin",
  "license": "MIT",
  "homepage": "https://smta.dev",
  "repository": {
    "type": "git",
    "url": "https://github.com/saas-multi-tenant-architecture/saasdb.git",
    "directory": "packages/better-auth"
  },
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "publishConfig": {
    "access": "public"
  },
  "files": [
    "dist",
    "sql",
    "sql-scripts.json"
  ],
  "scripts": {
    "build": "tsc --build",
    "lint": "tsc --noEmit"
  },
  "peerDependencies": {
    "better-auth": ">=1.0.0",
    "pg": ">=8.0.0"
  },
  "devDependencies": {
    "@types/pg": "^8.0.0",
    "typescript": "^5.0.0"
  }
}
```

- [ ] **Step 2: Create `tsconfig.json`**

Create `packages/better-auth/tsconfig.json` (matches `@smta/payload` exactly):

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "lib": ["ES2020"],
    "strict": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "composite": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 3: Create `sql-scripts.json`**

Create `packages/better-auth/sql-scripts.json`:

```json
{
  "version": "1.0",
  "description": "better-auth adapter SQL — session-variable auth implementation and new-user trigger",
  "scripts": [
    "sql/init/auth_better_auth_impl.sql",
    "sql/init/new_user_trigger.sql"
  ]
}
```

- [ ] **Step 4: Update `pnpm-workspace.yaml`**

Current content:
```yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

The glob `packages/*` already covers `packages/better-auth` — no change needed. Verify by running:

```bash
pnpm list --recursive --depth=0 2>/dev/null | head -20
```

If `@smta/better-auth` does not appear, explicitly add it:
```yaml
packages:
  - 'packages/*'
  - 'apps/*'
```
(The glob should cover it. If pnpm version requires explicit listing, add `- 'packages/better-auth'`.)

- [ ] **Step 5: Install dependencies**

```bash
pnpm install
```

Expected: pnpm resolves workspace with new package, no errors.

- [ ] **Step 6: Commit**

```bash
git add packages/better-auth/package.json packages/better-auth/tsconfig.json packages/better-auth/sql-scripts.json
git commit -m "feat: scaffold @smta/better-auth package structure"
```

---

### Task 2: SQL — `core.get_current_user_id()` Implementation (TDD)

**Files:**
- Create: `tests/adapters/01_better_auth_adapter.sql` (partial — auth impl tests only)
- Create: `packages/better-auth/sql/init/auth_better_auth_impl.sql`

- [ ] **Step 1: Create tests directory and write the failing test**

```bash
mkdir -p tests/adapters
```

Create `tests/adapters/01_better_auth_adapter.sql` with just the auth impl tests for now:

```sql
-- 01_better_auth_adapter.sql
-- Purpose: Verify @smta/better-auth adapter — auth impl, new-user trigger, and RLS chain.
-- Run standalone against a better-auth-deployed database:
--   pg_prove -v <db_url> tests/adapters/01_better_auth_adapter.sql

BEGIN;

SELECT plan(8);

-- ========================================
-- SECTION 1: core.get_current_user_id()
-- Tests that the better-auth impl reads from app.current_user_id
-- ========================================

-- Set a known UUID and verify the function returns it
SELECT set_config('app.current_user_id', 'aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa', true);

SELECT is(
  core.get_current_user_id(),
  'aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa'::UUID,
  'get_current_user_id() returns UUID from app.current_user_id when set'
);

-- Set a different UUID to verify it reads the current value (not cached)
SELECT set_config('app.current_user_id', 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb', true);

SELECT is(
  core.get_current_user_id(),
  'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'::UUID,
  'get_current_user_id() returns updated UUID after config change'
);

-- Clear the setting and verify NULL is returned (not an exception)
SELECT set_config('app.current_user_id', '', true);

SELECT is(
  core.get_current_user_id(),
  NULL::UUID,
  'get_current_user_id() returns NULL when app.current_user_id is empty string'
);

-- ========================================
-- SECTION 2: new-user trigger
-- Tests that INSERT into better-auth user table creates core.users_meta
-- ========================================

-- Create a minimal user table stub for trigger testing
-- (If better-auth is deployed, this is a no-op; trigger will already exist)
CREATE TABLE IF NOT EXISTS "user" (
  id TEXT NOT NULL PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ DEFAULT NOW()
);

-- Attach the trigger function (idempotent — safe to run in any env)
DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
CREATE TRIGGER trg_on_better_auth_user_created
AFTER INSERT ON "user"
FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();

-- Insert a valid UUID user — trigger should create users_meta row
INSERT INTO "user" (id, email, name)
VALUES ('cccccccc-3333-3333-3333-cccccccccccc', 'trigger@test.example.com', 'Trigger Test');

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.users_meta
    WHERE id = 'cccccccc-3333-3333-3333-cccccccccccc'::UUID
      AND email = 'trigger@test.example.com'
  ),
  'INSERT into user table creates corresponding core.users_meta row'
);

-- Verify email is copied correctly
SELECT is(
  (SELECT email FROM core.users_meta WHERE id = 'cccccccc-3333-3333-3333-cccccccccccc'::UUID),
  'trigger@test.example.com',
  'users_meta.email matches better-auth user email'
);

-- Non-UUID id should raise an exception from the ::UUID cast in the trigger
SELECT throws_ok(
  $$INSERT INTO "user" (id, email) VALUES ('not-a-uuid', 'bad@example.com')$$,
  'invalid input syntax for type uuid: "not-a-uuid"',
  'non-UUID id raises cast exception — enforces UUID configuration requirement'
);

-- ========================================
-- SECTION 3: RLS chain end-to-end
-- Tests that app.current_user_id drives SMTA RLS correctly
-- Requires fixture data: org aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa must exist
-- and user maria@test.bellaitalia.com must be a member.
-- ========================================

-- Set user who has membership in the Bella Italia org
SELECT test_helpers.set_auth_user(
  test_helpers.get_test_user_id('maria@test.bellaitalia.com')
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM core.organizations
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'RLS: org member can see their organization'
);

-- Set a user with no memberships — should see zero organizations
SELECT set_config('app.current_user_id', 'ffffffff-ffff-ffff-ffff-ffffffffffff', true);

SELECT is(
  (SELECT count(*)::int FROM core.organizations),
  0,
  'RLS: user with no memberships sees zero organizations'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
pg_prove -v "postgresql://postgres:postgres@localhost:54322/postgres" \
  tests/adapters/01_better_auth_adapter.sql
```

Expected output: FAIL. The first three tests may pass (if Supabase adapter is not deployed with `auth.uid()` path) or fail depending on which adapter is currently deployed. The trigger tests will fail with "function core.handle_new_better_auth_user() does not exist".

- [ ] **Step 3: Write `auth_better_auth_impl.sql`**

Create `packages/better-auth/sql/init/auth_better_auth_impl.sql`:

```sql
-- auth_better_auth_impl.sql
-- Purpose: better-auth implementation of core.get_current_user_id().
-- Reads the user UUID from a PostgreSQL session variable set by the
-- withSMTA() transaction wrapper in @smta/better-auth.
-- Identical mechanism to @smta/payload — no Supabase dependency.

CREATE OR REPLACE FUNCTION core.get_current_user_id()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = core, public;
```

- [ ] **Step 4: Apply the SQL to the test database**

```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" \
  -f packages/better-auth/sql/init/auth_better_auth_impl.sql
```

Expected: `CREATE FUNCTION`

- [ ] **Step 5: Run just the auth impl tests (first 3) to verify they pass**

```bash
pg_prove -v "postgresql://postgres:postgres@localhost:54322/postgres" \
  tests/adapters/01_better_auth_adapter.sql
```

Expected: First 3 tests pass (get_current_user_id tests). Trigger tests still fail — `core.handle_new_better_auth_user` does not exist yet.

- [ ] **Step 6: Commit**

```bash
git add packages/better-auth/sql/init/auth_better_auth_impl.sql \
        tests/adapters/01_better_auth_adapter.sql
git commit -m "feat(better-auth): add core.get_current_user_id() session-variable implementation"
```

---

### Task 3: SQL — New User Trigger (TDD)

**Files:**
- Create: `packages/better-auth/sql/init/new_user_trigger.sql`

- [ ] **Step 1: Write `new_user_trigger.sql`**

Create `packages/better-auth/sql/init/new_user_trigger.sql`:

```sql
-- new_user_trigger.sql
-- Purpose: Auto-create core.users_meta row when a user is created in better-auth.
-- Replaces the auth.users trigger used by @smta/supabase.
--
-- PREREQUISITE: Run better-auth's database migration before applying this file.
-- The trigger attaches only if the "user" table already exists, so deploying
-- this before better-auth's migration is a no-op (safe but incomplete).

-- ========================================
-- FUNCTION: core.handle_new_better_auth_user()
-- ========================================
CREATE OR REPLACE FUNCTION core.handle_new_better_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = core
AS $$
BEGIN
  INSERT INTO core.users_meta (id, email)
  VALUES (NEW.id::UUID, NEW.email);
  RETURN NEW;
END;
$$;

-- ========================================
-- TRIGGER (conditional — only if user table exists)
-- ========================================
-- Attach trigger only when better-auth's user table is present.
-- If better-auth migration has not run, deploying this file is safe —
-- the function is created but the trigger is deferred.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'user'
  ) THEN
    DROP TRIGGER IF EXISTS trg_on_better_auth_user_created ON "user";
    CREATE TRIGGER trg_on_better_auth_user_created
    AFTER INSERT ON "user"
    FOR EACH ROW EXECUTE FUNCTION core.handle_new_better_auth_user();
  END IF;
END $$;
```

- [ ] **Step 2: Apply the SQL to the test database**

```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" \
  -f packages/better-auth/sql/init/new_user_trigger.sql
```

Expected: `CREATE FUNCTION`, then `DO` (the trigger is NOT attached because `"user"` table doesn't exist in the Supabase test database — that's expected).

- [ ] **Step 3: Run all adapter tests to verify they now pass**

```bash
pg_prove -v "postgresql://postgres:postgres@localhost:54322/postgres" \
  tests/adapters/01_better_auth_adapter.sql
```

Expected: All 8 tests pass. The test file creates the `"user"` table stub and trigger within the transaction, runs trigger tests, then ROLLBACKs.

- [ ] **Step 4: Verify the full existing test suite still passes**

```bash
npm test
```

Expected: All 508 tests pass. The better-auth SQL changes only override `core.get_current_user_id()` (which `test_helpers.set_auth_user()` already sets correctly via `app.current_user_id`) and add a trigger function to a non-existent table — no regressions.

- [ ] **Step 5: Commit**

```bash
git add packages/better-auth/sql/init/new_user_trigger.sql
git commit -m "feat(better-auth): add new-user trigger to sync better-auth users to core.users_meta"
```

---

### Task 4: TypeScript — `inject-user-context.ts`

**Files:**
- Create: `packages/better-auth/src/middleware/inject-user-context.ts`

- [ ] **Step 1: Write `inject-user-context.ts`**

Create `packages/better-auth/src/middleware/inject-user-context.ts`:

```typescript
// inject-user-context.ts
// Sets app.current_user_id as a transaction-local PostgreSQL session variable.
// Must be called within a transaction — set_config(..., true) is scoped to the
// current transaction and cleared automatically on commit or rollback.

import type { Pool, PoolClient } from 'pg';

export async function injectUserContext(
  client: PoolClient,
  userId: string
): Promise<void> {
  await client.query(
    `SELECT set_config('app.current_user_id', $1, true)`,
    [userId]
  );
}

export async function clearUserContext(client: PoolClient): Promise<void> {
  await client.query(
    `SELECT set_config('app.current_user_id', '', true)`
  );
}

export async function withSMTA<T>(
  pool: Pool,
  userId: string | null | undefined,
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (userId) {
      await injectUserContext(client, userId);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd packages/better-auth && pnpm lint
```

Expected: No errors. (Note: `pg` types are devDependencies; `skipLibCheck: true` in tsconfig handles any peer type issues.)

- [ ] **Step 3: Commit**

```bash
git add packages/better-auth/src/middleware/inject-user-context.ts
git commit -m "feat(better-auth): add withSMTA() transaction wrapper and user context helpers"
```

---

### Task 5: TypeScript — `plugin/session.ts`

**Files:**
- Create: `packages/better-auth/src/plugin/session.ts`

- [ ] **Step 1: Write `session.ts`**

This file declares the TypeScript types for session augmentation and the `smtaSetActiveOrg` endpoint handler. The exact better-auth plugin API for session fields should be verified against current better-auth docs (version in use) — the structure below matches better-auth's `schema` + `additionalFields` plugin pattern as of v1.x.

Create `packages/better-auth/src/plugin/session.ts`:

```typescript
// session.ts
// Declares the activeOrgId field added to the better-auth session by smtaPlugin.
// activeOrgId tracks which SMTA organization is currently "in context" for
// multi-org users. It is set by the client via smtaSetActiveOrg().
// The user's role within that org is NOT stored here — it goes stale as
// memberships change and must be fetched on demand.

import type { Pool } from 'pg';

export interface SMTASessionFields {
  activeOrgId: string | null;
}

// Schema extension for better-auth — adds activeOrgId to the session table.
// See: https://www.better-auth.com/docs/plugins/create-your-own#schema
export const smtaSessionSchema = {
  session: {
    fields: {
      activeOrgId: {
        type: 'string' as const,
        nullable: true,
        defaultValue: null,
      },
    },
  },
};

// Handler for the smtaSetActiveOrg endpoint.
// Updates activeOrgId in the session record.
// pool is passed in from the plugin factory closure.
export async function handleSetActiveOrg(
  pool: Pool,
  sessionId: string,
  orgId: string | null
): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query(
      `UPDATE session SET "activeOrgId" = $1 WHERE id = $2`,
      [orgId, sessionId]
    );
  } finally {
    client.release();
  }
}
```

**Note:** better-auth's session table name and column quoting conventions should be verified in the installed version. If better-auth uses a different table name (e.g., `"session"` vs `session`) or stores session data differently, adjust the UPDATE query accordingly.

- [ ] **Step 2: Compile check**

```bash
cd packages/better-auth && pnpm lint
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add packages/better-auth/src/plugin/session.ts
git commit -m "feat(better-auth): add activeOrgId session schema and handler"
```

---

### Task 6: TypeScript — `plugin/endpoints.ts`

**Files:**
- Create: `packages/better-auth/src/plugin/endpoints.ts`

- [ ] **Step 1: Write `endpoints.ts`**

Each endpoint wraps an SMTA `public.*` function. The endpoint calls `withSMTA()` using the session's `user.id`, so SMTA's RLS is enforced at the DB layer.

**Verify the exact better-auth endpoint creation API** (`createAuthEndpoint`, session access, body/query parsing) against the installed better-auth version's docs before implementing. The structure below reflects the better-auth v1.x plugin endpoint pattern.

Create `packages/better-auth/src/plugin/endpoints.ts`:

```typescript
// endpoints.ts
// Wraps SMTA public.* functions as better-auth auth.api.* endpoints.
// Each endpoint enforces RLS via withSMTA() — users can only affect
// organizations they are members of, enforced at the database layer.
//
// Verify createAuthEndpoint import path against installed better-auth version.
// Common paths: 'better-auth/api' or 'better-auth/plugins'

import type { Pool, PoolClient } from 'pg';
import { withSMTA } from '../middleware/inject-user-context';
import { handleSetActiveOrg } from './session';

export interface EndpointOptions {
  pool: Pool;
}

// Helper: run a public.* function and return its first row result
async function callPublicFn(
  client: PoolClient,
  fnName: string,
  args: unknown[]
): Promise<unknown> {
  const placeholders = args.map((_, i) => `$${i + 1}`).join(', ');
  const sql = `SELECT * FROM ${fnName}(${placeholders})`;
  const result = await client.query(sql, args);
  return result.rows;
}

// Factory that returns all SMTA endpoint handlers given a pool.
// These are attached to the better-auth plugin's `endpoints` map in plugin/index.ts.
// The actual createAuthEndpoint() wiring lives there to keep this file
// focused on the SMTA logic.
export function createSMTAHandlers(pool: Pool) {
  return {
    async createOrganization(userId: string, name: string, description?: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.create_organization', [name, description ?? null])
      );
    },

    async listOrganizations(userId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.list_my_organizations', [])
      );
    },

    async getOrganization(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.get_organization', [orgId])
      );
    },

    async createInvitation(userId: string, orgId: string, email: string, roleId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.create_invitation', [orgId, email, roleId])
      );
    },

    async acceptInvitation(userId: string, token: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.accept_invitation', [token])
      );
    },

    async getInvitationDetails(token: string) {
      // get_invitation_details is intentionally anon-callable (invitation landing page)
      // No RLS enforcement needed — called without a user context
      const client = await pool.connect();
      try {
        return (await callPublicFn(client, 'public.get_invitation_details', [token]));
      } finally {
        client.release();
      }
    },

    async listInvitations(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.list_invitations', [orgId])
      );
    },

    async listOrgMembers(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.list_organization_members', [orgId])
      );
    },

    async getUserPermissions(userId: string, orgId: string) {
      return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.get_user_permissions', [orgId])
      );
    },

    async setActiveOrg(pool: Pool, sessionId: string, orgId: string | null) {
      return handleSetActiveOrg(pool, sessionId, orgId);
    },
  };
}
```

- [ ] **Step 2: Compile check**

```bash
cd packages/better-auth && pnpm lint
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add packages/better-auth/src/plugin/endpoints.ts
git commit -m "feat(better-auth): add SMTA endpoint handlers wrapping public.* functions"
```

---

### Task 7: TypeScript — `plugin/index.ts` and `src/index.ts`

**Files:**
- Create: `packages/better-auth/src/plugin/index.ts`
- Create: `packages/better-auth/src/index.ts`

- [ ] **Step 1: Write `plugin/index.ts`**

This file wires the handlers from `endpoints.ts` into better-auth's plugin format. The `createAuthEndpoint` import and session middleware access **must be verified against the installed better-auth version** — check `node_modules/better-auth/` exports or the better-auth docs.

Create `packages/better-auth/src/plugin/index.ts`:

```typescript
// plugin/index.ts
// Composes the smtaPlugin for registration in better-auth's auth config.
//
// If TypeScript errors appear on createAuthEndpoint or sessionMiddleware imports,
// check the installed version:
//   cat node_modules/better-auth/package.json | grep '"version"'
// better-auth may export these from 'better-auth/api' or 'better-auth/plugins'.

import type { BetterAuthPlugin } from 'better-auth';
import { createAuthEndpoint, sessionMiddleware } from 'better-auth/api';
import { z } from 'zod';
import type { Pool } from 'pg';
import { smtaSessionSchema, type SMTASessionFields } from './session';
import { createSMTAHandlers } from './endpoints';

export interface SMTAPluginOptions {
  pool: Pool;
}

export function smtaPlugin(options: SMTAPluginOptions): BetterAuthPlugin {
  const handlers = createSMTAHandlers(options.pool);

  return {
    id: 'smta',

    // Extends the session table with activeOrgId.
    // Run better-auth's migration after adding this plugin to create the column.
    schema: smtaSessionSchema,

    // Type inference for session augmentation.
    // Consumers access: session.activeOrgId (string | null)
    $InferServerSession: {} as {
      activeOrgId: SMTASessionFields['activeOrgId'];
    },

    endpoints: {
      smtaCreateOrganization: createAuthEndpoint(
        '/smta/organization',
        { method: 'POST', body: z.object({ name: z.string(), description: z.string().optional() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.createOrganization(session.user.id, ctx.body.name, ctx.body.description);
          return ctx.json(result);
        }
      ),

      smtaListOrganizations: createAuthEndpoint(
        '/smta/organizations',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.listOrganizations(session.user.id);
          return ctx.json(result);
        }
      ),

      smtaGetOrganization: createAuthEndpoint(
        '/smta/organization/:orgId',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.getOrganization(session.user.id, ctx.params.orgId);
          return ctx.json(result);
        }
      ),

      smtaCreateInvitation: createAuthEndpoint(
        '/smta/invitation',
        { method: 'POST', body: z.object({ orgId: z.string(), email: z.string(), roleId: z.string() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.createInvitation(session.user.id, ctx.body.orgId, ctx.body.email, ctx.body.roleId);
          return ctx.json(result);
        }
      ),

      smtaAcceptInvitation: createAuthEndpoint(
        '/smta/invitation/accept',
        { method: 'POST', body: z.object({ token: z.string() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.acceptInvitation(session.user.id, ctx.body.token);
          return ctx.json(result);
        }
      ),

      smtaGetInvitationDetails: createAuthEndpoint(
        '/smta/invitation/:token',
        { method: 'GET' },
        async (ctx) => {
          const result = await handlers.getInvitationDetails(ctx.params.token);
          return ctx.json(result);
        }
      ),

      smtaListInvitations: createAuthEndpoint(
        '/smta/organization/:orgId/invitations',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.listInvitations(session.user.id, ctx.params.orgId);
          return ctx.json(result);
        }
      ),

      smtaListOrgMembers: createAuthEndpoint(
        '/smta/organization/:orgId/members',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.listOrgMembers(session.user.id, ctx.params.orgId);
          return ctx.json(result);
        }
      ),

      smtaGetUserPermissions: createAuthEndpoint(
        '/smta/organization/:orgId/permissions',
        { method: 'GET', use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          const result = await handlers.getUserPermissions(session.user.id, ctx.params.orgId);
          return ctx.json(result);
        }
      ),

      smtaSetActiveOrg: createAuthEndpoint(
        '/smta/active-org',
        { method: 'POST', body: z.object({ orgId: z.string().nullable() }), use: [sessionMiddleware] },
        async (ctx) => {
          const session = ctx.context.session;
          await handlers.setActiveOrg(options.pool, session.id, ctx.body.orgId);
          return ctx.json({ success: true });
        }
      ),
    },
  } satisfies BetterAuthPlugin;
}

- [ ] **Step 2: Write `src/index.ts`**

Create `packages/better-auth/src/index.ts`:

```typescript
export { smtaPlugin } from './plugin/index';
export type { SMTAPluginOptions } from './plugin/index';
export type { SMTASessionFields } from './plugin/session';
export { withSMTA, injectUserContext, clearUserContext } from './middleware/inject-user-context';
```

- [ ] **Step 3: Compile check**

```bash
cd packages/better-auth && pnpm lint
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add packages/better-auth/src/plugin/index.ts packages/better-auth/src/index.ts
git commit -m "feat(better-auth): add smtaPlugin factory and package exports"
```

---

### Task 8: Build Integration

**Files:**
- Modify: `scripts/combine_files.js`
- Modify: `package.json` (root)

- [ ] **Step 1: Update `combine_files.js` to add `better-auth` adapter**

Current line 4:
```javascript
const ADAPTERS = ['supabase', 'payload']
```

Change to:
```javascript
const ADAPTERS = ['supabase', 'payload', 'better-auth']
```

No other changes needed — the rest of the script is adapter-agnostic.

- [ ] **Step 2: Add `build:better-auth` script to root `package.json`**

Current scripts section:
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

Change to:
```json
"scripts": {
  "test": "./scripts/run_tests.sh",
  "build:supabase": "node ./scripts/combine_files.js --adapter supabase",
  "build:payload": "node ./scripts/combine_files.js --adapter payload",
  "build:better-auth": "node ./scripts/combine_files.js --adapter better-auth",
  "build": "npm run build:supabase && npm run build:payload && npm run build:better-auth",
  "build:docs": "pnpm --filter @smta/docs build",
  "release": "changeset publish"
}
```

- [ ] **Step 3: Test the build script**

```bash
npm run build:better-auth
```

Expected output:
```
2 files combined into output/SMTA-better-auth-<timestamp>.sql
```

Verify the output file contains both SQL files in order:
```bash
ls -t output/SMTA-better-auth-*.sql | head -1 | xargs grep -c "get_current_user_id"
```
Expected: `1` (the function appears once)

```bash
ls -t output/SMTA-better-auth-*.sql | head -1 | xargs grep -c "handle_new_better_auth_user"
```
Expected: `1`

- [ ] **Step 4: Build the TypeScript package**

```bash
cd packages/better-auth && pnpm build
```

Expected: `dist/` directory created with `index.js`, `index.d.ts`, and all subdirectory files.

- [ ] **Step 5: Commit**

```bash
git add scripts/combine_files.js package.json packages/better-auth/dist
git commit -m "feat(better-auth): add build:better-auth script and compile TypeScript"
```

---

### Task 9: README

**Files:**
- Create: `packages/better-auth/README.md`

- [ ] **Step 1: Write `README.md`**

Create `packages/better-auth/README.md`:

```markdown
# @smta/better-auth

better-auth adapter for SMTA — wires better-auth's session identity into SMTA's PostgreSQL RLS enforcement, and exposes SMTA's tenant management functions as `auth.api.smta*` endpoints.

## What this does

- **Auth wiring:** Implements `core.get_current_user_id()` to read from `app.current_user_id` — the same session variable set by `withSMTA()` on each request. SMTA's RLS policies use this to filter rows.
- **User sync:** A trigger on better-auth's `user` table auto-creates `core.users_meta` rows on signup.
- **Plugin:** Adds `auth.api.smtaCreateOrganization()`, `auth.api.smtaListOrganizations()`, and other tenant management endpoints to the better-auth client. Adds `activeOrgId` to the session.
- **`withSMTA()`:** Transaction wrapper for Next.js Route Handlers and Server Actions.

## Prerequisites

1. Better-auth configured with UUID generation:

```typescript
export const auth = betterAuth({
  generateId: () => crypto.randomUUID(), // required — SMTA uses UUID primary keys
  plugins: [smtaPlugin({ pool })],
});
```

2. Run better-auth's migration **before** applying the SMTA SQL (the new-user trigger targets better-auth's `user` table):

```bash
# 1. Run better-auth migration (creates user, session, account, verification tables)
npx better-auth migrate

# 2. Apply SMTA better-auth adapter
psql $DATABASE_URL -f output/SMTA-better-auth-<timestamp>.sql
```

## Deployment

```bash
# Generate combined SQL deployment script
npm run build:better-auth
# → output/SMTA-better-auth-<timestamp>.sql
```

The output script contains `@smta/core` (all 56 files) followed by the 2 better-auth adapter files.

## Usage

### `withSMTA()` in a Route Handler

```typescript
import { auth } from '@/lib/auth';
import { withSMTA } from '@smta/better-auth';
import { pool } from '@/lib/db';

export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });

  return withSMTA(pool, session?.user?.id, async (client) => {
    const { rows } = await client.query(
      'SELECT * FROM public.list_my_organizations()'
    );
    return Response.json(rows);
  });
}
```

### Plugin registration

```typescript
import { betterAuth } from 'better-auth';
import { smtaPlugin } from '@smta/better-auth';
import { pool } from '@/lib/db';

export const auth = betterAuth({
  generateId: () => crypto.randomUUID(),
  plugins: [smtaPlugin({ pool })],
});
```

### Next.js `proxy.ts` (auth protection)

Use better-auth's standard Next.js proxy pattern. See better-auth docs for the current `proxy.ts` API (replaced deprecated `middleware.ts` in Next.js post-2025).

## Running the adapter tests

The pgTap test file requires a database with the better-auth adapter deployed (not the Supabase adapter):

```bash
pg_prove -v "postgresql://<user>:<password>@<host>:<port>/<db>" \
  tests/adapters/01_better_auth_adapter.sql
```

The test file also requires the standard SMTA fixture data (test users, Bella Italia org). Load fixtures first:

```bash
psql $DATABASE_URL -f tests/fixtures/00_test_helpers.sql
psql $DATABASE_URL -f tests/fixtures/01_roles.sql
psql $DATABASE_URL -f tests/fixtures/02_test_users.sql
psql $DATABASE_URL -f tests/fixtures/03_bella_italia.sql
```

## Better-auth version compatibility

This package was designed for better-auth v1.x. Verify the `createAuthEndpoint` import path and session middleware access in `src/plugin/index.ts` against your installed version:

```bash
cat node_modules/better-auth/package.json | grep '"version"'
```

## User table name

By default targets better-auth's `"user"` table in the `public` schema. If you configure a table prefix (e.g. `tablePrefix: 'ba_'`), update the trigger target in `sql/init/new_user_trigger.sql` from `"user"` to `"ba_user"` and regenerate the deployment script.
```

- [ ] **Step 2: Commit**

```bash
git add packages/better-auth/README.md
git commit -m "docs(better-auth): add @smta/better-auth README with setup and usage guide"
```

---

## Post-Implementation Checklist

- [ ] `npm run build:better-auth` produces a valid SQL file
- [ ] Adapter SQL applied to a better-auth-deployed database without errors
- [ ] `pg_prove` adapter test file passes all 8 tests
- [ ] `npm test` (Supabase suite) still passes all 508 tests — no regressions
- [ ] `cd packages/better-auth && pnpm build` compiles cleanly
- [ ] `smtaPlugin` endpoints wired with `createAuthEndpoint()` for the installed better-auth version
- [ ] better-auth migration run before SMTA SQL applied (new-user trigger requires `user` table)
