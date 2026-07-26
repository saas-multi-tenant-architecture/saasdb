# Role labels across the API surface, and invitation cancel/resend

**Date:** 2026-07-26
**Source:** `docs/superpowers/smta-invitation-gaps.md`
**Packages:** `@smta/core`, `@smta/schemas`, `@smta/better-auth`
**Release:** one changeset, `minor` across the fixed group

## Problem

Two coverage gaps, both blocking the HelmetFires `/team` surface. Neither breaks
anything that works today.

**Gap 1.** `core.roles` carries an identifier (`name`) and a display label
(`description`). Eight functions project a role to a user-facing surface, and all
eight return only the identifier. Consumers render `operator` and
`general_manager` to end users, including on the invitation landing page — the
first thing an invited user ever sees.

Deriving the label from the identifier is wrong and quietly so: `super_admin`'s
label is `Owner`, so prettifying yields "Super Admin", a role that does not exist
in the product. It is also the highest-privilege role in the system. Every
consumer that de-slugifies gets that one wrong.

Each of the eight already joins `core.roles`. Returning the label costs nothing.

**Gap 2.** `public.cancel_invitation` and `public.resend_invitation` exist and are
well built — both authorise, both audit, and resend mints a fresh token, resets
`expires_at`, and flips `expired` back to `pending`. Neither is exposed by
`@smta/better-auth`. An application on the adapter can create and list
invitations but can never cancel or resend one. An invitation to a typo'd address
is permanent until it expires.

## Decisions

Recorded with reasoning, because several are load-bearing.

**Append, never rename.** `role_label` is added alongside the existing column.
Consumers key behaviour on the stable identifier and must keep getting it.
Renaming would break every consumer selecting by name.

**The existing `role` vs `role_name` inconsistency stays.** Standardising is
tempting while touching all ten definitions, but it is a breaking change for a
cosmetic gain. Resolve it in a separate, clearly-flagged major release, or not at
all.

**All eight in one release.** The alternative is a mixed contract where consumers
must remember which functions carry a label — worse than either end state.
`public.list_organization_members` matters most: it is the function that renders
an organisation's **Owner**, and invitations can never carry `super_admin` at all
(`core.create_invitation` rejects it; ownership transfer is
`public.transfer_super_admin`). A member roster mislabels the owner to everyone,
every time; the invitation functions can only ever mislabel the three lesser
roles.

**The label is emitted raw — `r.description AS role_label`, no `COALESCE`.**
`core.roles.description` is nullable and roles are seeded per deployment, so NULL
is a real state meaning "this deployment gave the role no label". Coalescing to
the identifier would render `super_admin` to an end user in exactly the case no
one thinks to test, reintroducing the original bug somewhere harder to find. A
missing label should look like a missing label.

**`@smta/schemas` types it as a required, nullable key** — `z.string().nullable()`,
not `.optional()`. All seven `@smta/*` packages are in one Changesets `fixed`
group, so `@smta/core` and `@smta/schemas` always publish at the same version: a
consumer on the new schemas package against an un-migrated database has a deploy
error, and should get a loud `ZodError` naming `role_label` at the first call
rather than a blank label in production. Optional would buy skew tolerance at the
cost of a permanent `string | null | undefined` that every consumer branches on
forever.

**The cancel endpoint returns `{ success: true }`, not the raw row.**
`public.cancel_invitation` returns `void`, and `callPublicFn` always runs
`SELECT * FROM fn(...)`, which for a void function yields one row with one
meaningless column. Passing it through would put `[{"cancel_invitation": ""}]` in
the public HTTP contract. `smtaSetActiveOrg` already sets the precedent of
normalising. This is the one handler that is not a pure pass-through.

**Branch, not worktree.** A worktree would need its own `pnpm install` across a
seven-package workspace before lint or build could run, for no isolation benefit
against a clean tree. Work happens on
`feat/invitation-role-labels-and-management`, left unmerged and unpushed.

## Scope

### In scope — eight public surfaces, ten function definitions

Six are public-only and build the `core.roles` join themselves. Two delegate to
`core`, so both halves move together.

| File | Function | Role columns after |
|---|---|---|
| `packages/core/sql/functions/invitations.sql` | `core.list_organization_invitations` | `role_name, role_label` |
| `packages/core/sql/functions/invitations.sql` | `core.get_invitation_by_token` | `role_name, role_label` |
| `packages/core/sql/public/functions/invitations.sql` | `public.list_invitations` | wrapper, mirrors core |
| `packages/core/sql/public/functions/invitations.sql` | `public.get_invitation_details` | wrapper, mirrors core |
| `packages/core/sql/public/functions/organizations.sql` | `public.list_organization_members` | `role, role_label` |
| `packages/core/sql/public/functions/organizations.sql` | `public.list_my_organizations` | `role, role_label` |
| `packages/core/sql/public/functions/units.sql` | `public.list_unit_members` | `role, role_label` |
| `packages/core/sql/public/functions/units.sql` | `public.list_my_units` | `role, role_label` |
| `packages/core/sql/public/functions/user_profile.sql` | `public.get_user_organizations` | `role, role_label` |
| `packages/core/sql/public/functions/user_profile.sql` | `public.get_user_units` | `role, role_label` |

### Out of scope, with reasons

- **`public.get_user_role`** — returns bare `text`, not a table. No column to
  append, and changing the return type breaks every caller. It reads as an
  identifier for logic, not for display.
- **`public.get_user_permissions`, `public.get_user_unit_permissions`** — return
  `role_name` + `casl_rules` to build a CASL Ability. Machine-facing; the label
  would be unused weight.
- **`public.get_organization`** — projects no role at all.
- **Renaming `role` → `role_name`** — see Decisions.

## Design

### SQL layer

Each of the ten gets `DROP FUNCTION IF EXISTS <signature>;` inline immediately
above its `CREATE OR REPLACE`. `CREATE OR REPLACE` cannot change a return type,
and inline drops match the existing convention at
`packages/core/sql/public/functions/user_profile.sql:36` and
`packages/core/sql/public/functions/organizations.sql:121`. Inline keeps each
function self-contained and idempotent when the combined script is re-run,
rather than adding a consolidated drop block to keep in sync by hand.

Drop signatures ignore defaults:

```
core.list_organization_invitations(UUID, TEXT)
core.get_invitation_by_token(TEXT)
public.list_invitations(UUID, TEXT)
public.get_invitation_details(TEXT)
public.list_organization_members(UUID)
public.list_my_organizations()
public.list_unit_members(UUID)
public.list_my_units()
public.get_user_organizations()
public.get_user_units(UUID)
```

The projection in every case:

```sql
  r.name        AS role_name,   -- or AS role, per the function's existing name
  r.description AS role_label,
```

`role_label` sits immediately after the role identifier rather than at the end of
the return table. For five of the ten that is the same position anyway; for
`list_organization_members`, `list_invitations`, and `get_invitation_details` it
is a mid-table insert. Safe: no test compares rows positionally (see Testing),
and every runtime consumer keys by name.

Resulting return tables:

```
core.list_organization_invitations  id, email, organization_id, unit_id,
                                    role_name, role_label, invited_by_email,
                                    status, expires_at, created_at
core.get_invitation_by_token        id, email, organization_name, unit_name,
                                    role_name, role_label, invited_by_name,
                                    expires_at, status
public.list_organization_members    user_id, email, first_name, last_name,
                                    role, role_label, is_super_admin
public.list_my_organizations        id, name, description, role, role_label
public.get_user_organizations       id, name, description, role, role_label
public.list_unit_members            user_id, email, first_name, last_name,
                                    role, role_label
public.list_my_units                id, organization_id, name, role, role_label
public.get_user_units               id, organization_id, name, role, role_label
```

In `list_my_organizations` and `get_user_organizations`, `description` is the
*organisation's* description and `role_label` is the *role's*. Two different
`description` columns, distinctly aliased. Do not conflate them.

#### Two ordering constraints

Both fail at call time, not deploy time. A deploy that misses either will look
clean.

1. **`public.get_user_organizations` is `RETURN QUERY SELECT * FROM
   public.list_my_organizations();`** Its `RETURNS TABLE` must gain `role_label`
   in the same position as its delegate, or every call raises a structure
   mismatch.
2. **`public.list_invitations` and `public.get_invitation_details` are likewise
   `SELECT * FROM core.…`,** with the same constraint against their core
   counterparts.

Note that `sql/public/functions/user_profile.sql` loads *before*
`organizations.sql` in `packages/core/sql-scripts.json`, so
`get_user_organizations` is created before its delegate exists. This already
works — plpgsql does not resolve function bodies at creation time — and the drop
ordering is safe for the same reason. No reordering is needed or wanted.

#### Grants

None of the ten appears in `packages/core/sql/public/grants.sql`. They all ride
the default `PUBLIC EXECUTE` grant, which `DROP` + `CREATE` re-establishes. Only
the explicitly-revoked admin functions would have been at risk, and none is in
scope. No grants file change.

### `@smta/schemas`

Six zod objects each gain `role_label: z.string().nullable()`. Six cover eight
functions because four share a shape.

| Schema | File | Covers |
|---|---|---|
| `invitationListItemSchema` | `rpc/invitations.ts` | `list_invitations` |
| `invitationDetailsSchema` | `rpc/invitations.ts` | `get_invitation_details` |
| `organizationMemberSchema` | `rpc/organizations.ts` | `list_organization_members` |
| `listMyOrganizationsItemSchema` | `rpc/organizations.ts` | `list_my_organizations`, `get_user_organizations` |
| `unitMemberSchema` | `rpc/units.ts` | `list_unit_members` |
| `userUnitSchema` | `rpc/user_profile.ts` | `list_my_units`, `get_user_units` |

The `SYNC-CHECK` header comments list parameters, not return columns, so they
need no edit. Nothing enforces them mechanically.

### `@smta/better-auth`

**Gap 1 needs no adapter change.** Handlers return `result.rows` verbatim, so
`role_label` flows through untouched. This is the payoff for fixing it in SQL:
the Supabase and payload adapters and direct SQL callers get it from the same
change.

**Gap 2 — two handlers in `src/plugin/endpoints.ts`:**

```ts
async cancelInvitation(userId: string, invitationId: string) {
  await withSMTA(pool, userId, (client) =>
    callPublicFn(client, 'public.cancel_invitation', [invitationId]));
  // public.cancel_invitation returns void; the row it yields is a SQL artifact,
  // not part of this endpoint's contract.
  return { success: true };
},

// NOTE: unlike list_invitations, this response carries the invitation TOKEN.
// resend_invitation mints a fresh one so the caller can re-send the email.
// list_invitations deliberately does not re-expose tokens; this endpoint must.
// Treat the response as a secret — do not log it.
async resendInvitation(userId: string, invitationId: string) {
  return withSMTA(pool, userId, (client) =>
    callPublicFn(client, 'public.resend_invitation', [invitationId]));
},
```

The parameter **must** be named `invitationId`. `tests/adapters/04_endpoint_arg_order.sh`
maps JS identifiers to the SQL parameter names they may legitimately bind to, and
already carries `invitationId → p_invitation_id p_id`. Renaming it fails the guard.

**Two endpoints in `src/plugin/index.ts`**, both `POST` with `sessionMiddleware`,
matching `smtaCreateInvitation`. The SQL functions do their own authorisation on
top.

```
POST /smta/invitation/:id/cancel  -> { "success": true }
POST /smta/invitation/:id/resend  -> [{ id, token, email, expires_at }]
```

No collision with the existing `GET /smta/invitation/:token` — different method
and segment count.

`packages/better-auth/dist/` is committed to this repository, so built output for
the better-auth and schemas packages is part of the deliverable, not a side
effect.

### Error handling

Unchanged, and deliberately so. All authorisation and validation stays in SQL,
which already raises with consumer-readable messages:
`cancel_invitation` refuses anything not `pending` and requires inviter or org
membership; `resend_invitation` requires org membership. Errors propagate as
thrown exceptions through `withSMTA`, exactly as for the four existing
invitation endpoints. No new error paths are introduced.

## Testing

### New: `tests/functions/06_role_labels.sql`

Registered in `scripts/run_tests.sh` immediately after
`tests/functions/05_permissions_functions.sql` — the runner lists files
explicitly and does not glob. One file rather than assertions scattered across
five existing ones, so the label contract has a single home and a ninth function
later has an obvious place to land.

Three groups of assertions:

1. **All eight functions return `role_label` matching `core.roles.description`.**
   Fixtures seed three roles, each with a non-null description (`super_admin` →
   "Organization owner with full administrative access"), so expected values are
   known.
2. **NULL passes through.** `UPDATE core.roles SET description = NULL` for one
   role inside the transaction, re-query one function, assert `role_label IS
   NULL`. Tests wrap in `BEGIN`/`ROLLBACK`, so this does not leak; nothing
   anywhere asserts an exact `core.roles` count, only existence and `> 0`.
3. **The identifier is unchanged** — a regression guard on the decision not to
   rename `role`/`role_name`.

### Existing coverage, verified sufficient

- **No existing pgTap test breaks.** Every `SELECT *` against the eight in the
  test suite is inside `throws_ok`, which never compares a result set. Nothing
  compares full rows positionally.
- **Gap 2 needs no new test file.** `tests/invitations/03_manage_invitations.sql`
  already asserts cancel and resend semantics across 16 checks: non-member
  rejection, non-pending refusal, token rotation, and expiry reset.
- **The adapter binding is already guarded.**
  `tests/adapters/04_endpoint_arg_order.sh` globs `tests/adapters/*.sh`, greps
  every `callPublicFn` site, and validates each positionally against live
  `pg_proc`. It picks up the new call sites automatically — this is the
  real-database integration check a mocked test structurally cannot provide.
  Confirm the site count rises from 9 to 11 rather than assuming it.

### Also run

- `pnpm --filter @smta/better-auth lint` (`tsc --noEmit`) and a build.
- The full pgTap suite against a live database. Baseline is 508 assertions; the
  new file adds roughly ten. Report actual output. If no database is reachable,
  say so plainly rather than claim a pass.

## Documentation

- `apps/docs/src/content/docs/adapters/better-auth.mdx` — two rows in the
  endpoint table, with the token-is-a-secret note on resend.
- `apps/docs/src/content/docs/rpc-reference/invitations.mdx`,
  `organizations.mdx`, `units.mdx`, `user-profile.mdx` — `role_label` in each
  return-column table, documented as nullable.

## Release

One changeset, `minor` across the fixed group: new columns and new endpoints are
additive features, not fixes. Per the two-stage Changesets setup, merging
publishes nothing — the changeset queues the bump. The branch stays unmerged and
unpushed pending other in-flight work.
