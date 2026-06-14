# @smta/better-auth Documentation Update — Design Spec

## Goal

Add `@smta/better-auth` to all existing documentation surfaces: the Starlight site at `smta.dev` and the in-repo markdown files. Incidentally clean up `installation.mdx` by removing the Supabase-specific pg-graphql block (already present in the Supabase-specific pages).

## Scope

### New files (Starlight site)

| File | Description |
|---|---|
| `apps/docs/src/content/docs/getting-started/quickstart-better-auth.mdx` | Step-by-step quick start for the better-auth adapter |
| `apps/docs/src/content/docs/adapters/better-auth.mdx` | Adapter reference page |

### Modified files (Starlight site)

| File | Changes |
|---|---|
| `apps/docs/astro.config.mjs` | Add Quick Start: better-auth to Getting Started sidebar; add Better Auth to Adapters sidebar |
| `apps/docs/src/content/docs/getting-started/installation.mdx` | Remove pg-graphql block; make prerequisites adapter-neutral; add better-auth CLI option; add better-auth quickstart to Next Steps |
| `apps/docs/src/content/docs/getting-started/what-is-smta.mdx` | Update Three Layers table and "What SMTA Does Not Provide" to include better-auth |
| `apps/docs/src/content/docs/architecture/adapter-pattern.mdx` | Add better-auth adapter implementation block; add row to Package Boundaries table |

### Modified files (in-repo markdown)

| File | Changes |
|---|---|
| `README.md` | Layer diagram, Extensible Connections, Goals, Project Structure, Package Boundaries, Deployment, test count |
| `TESTING.md` | Add `tests/adapters/` as category 8 in the test structure list |
| `packages/cli/README.md` | Add `better-auth` to `--adapter` table and usage examples |
| `packages/better-auth/README.md` | Update "Running the adapter tests" section: tests now run via `pnpm test`; standalone instructions kept for reference |
| `packages/core/README.md` | Add `@smta/better-auth` to package family table |
| `packages/supabase/README.md` | Add `@smta/better-auth` to package family table |
| `packages/payload/README.md` | Add `@smta/better-auth` to package family table |

---

## New Page: `quickstart-better-auth.mdx`

Five-step structure mirroring `quickstart-payload.mdx`:

1. **Prerequisites** — better-auth v1.x project with PostgreSQL; `generateId: () => crypto.randomUUID()` configured (SMTA requires UUID primary keys); better-auth migration run before applying SMTA SQL (the new-user trigger targets better-auth's `user` table).

2. **Generate and Apply the SQL**
   ```bash
   npx @smta/cli --adapter better-auth
   # → SMTA-better-auth-<timestamp>.sql  (60 SQL files combined)
   psql "$DATABASE_URL" -f SMTA-better-auth-<timestamp>.sql
   ```

3. **What the Adapter Provides** — table:

   | File | Purpose |
   |---|---|
   | `auth_better_auth_impl.sql` | Implements `core.get_current_user_id()` via the `app.current_user_id` session variable |
   | `new_user_trigger.sql` | Auto-creates `core.users_meta` rows when a user is inserted into better-auth's `user` table |

4. **Register the Plugin** — two code blocks:
   - `auth.ts`: `betterAuth({ generateId: () => crypto.randomUUID(), plugins: [smtaPlugin({ pool })] })`
   - Route Handler: `withSMTA(pool, session?.user?.id, async (client) => { ... })`

5. **Verify**
   ```sql
   set app.current_user_id = 'your-user-uuid-here';
   select public.list_my_organizations();
   ```

---

## New Page: `adapters/better-auth.mdx`

Structure mirroring `adapters/payload.mdx`:

### What It Contains

| File | Purpose |
|---|---|
| `auth_better_auth_impl.sql` | Implements `core.get_current_user_id()` via `app.current_user_id` session variable |
| `new_user_trigger.sql` | Trigger on better-auth's `user` table → creates `core.users_meta` on signup |

### Auth Implementation

Shows the `get_current_user_id()` SQL (identical to Payload's implementation — session variable pattern). Explains that `withSMTA()` sets this variable at the start of each request via `SET LOCAL`, scoping it to the transaction.

```typescript
// withSMTA() sets app.current_user_id for the duration of the callback
export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });
  return withSMTA(pool, session?.user?.id, async (client) => {
    const { rows } = await client.query('SELECT * FROM public.list_my_organizations()');
    return Response.json(rows);
  });
}
```

### User Sync

Unique to the better-auth adapter: a trigger on better-auth's `user` table auto-creates `core.users_meta` on signup. Notes the `generateId: () => crypto.randomUUID()` requirement (SMTA's `users_meta.id` is UUID; the trigger casts better-auth's `TEXT` id to `UUID`).

### Plugin Endpoints

`smtaPlugin()` adds the following to `auth.api.*`:

| Endpoint | Method | Description |
|---|---|---|
| `smtaCreateOrganization` | POST | Create a new organization |
| `smtaListOrganizations` | GET | List organizations the user is a member of |
| `smtaGetOrganization` | GET | Get a single organization |
| `smtaCreateInvitation` | POST | Invite a user to an organization |
| `smtaAcceptInvitation` | POST | Accept an invitation by token |
| `smtaGetInvitationDetails` | GET | Get invitation details (public, no auth required) |
| `smtaListInvitations` | GET | List pending invitations for an organization |
| `smtaListOrgMembers` | GET | List members of an organization |
| `smtaGetUserPermissions` | GET | Get the current user's permissions within an org |
| `smtaSetActiveOrg` | POST | Set the active organization in the session |

Also adds `activeOrgId` to the session schema (nullable string tracking which org is currently in context for multi-org users).

### Secrets

Same note as Payload: `core.store_secret_impl()` and `core.delete_secret_impl()` remain as exception-raising stubs. Implement your own vault adapter if you need per-tenant secrets.

### Deployment

```bash
npx @smta/cli --adapter better-auth
# → SMTA-better-auth-<timestamp>.sql  (60 SQL files combined)
```

---

## Key Numbers

| Adapter | SQL files |
|---|---|
| `@smta/supabase` | 59 |
| `@smta/payload` | 57 |
| `@smta/better-auth` | 60 |

Test suite: **41 files, 506 tests** (498 SMTA + 8 adapter tests).

---

## pg-graphql Cleanup

`installation.mdx` currently contains a full pg-graphql warning block that is Supabase-specific. This block already appears in both `quickstart-supabase.mdx` and `adapters/supabase.mdx`. The change is a deletion from `installation.mdx` only — no new content needed on the Supabase pages.

---

## Out of Scope

- smta.dev deployment / Cloudflare Pages configuration
- Changeset or npm publish for `@smta/cli` (already handled separately)
- RPC reference pages (no better-auth-specific RPC functions — all `public.*` functions are adapter-agnostic)
- Billing or CASL integration pages (no better-auth-specific content)
