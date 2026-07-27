# @smta/core

## 0.7.0

### Minor Changes

- 700f06e: Return the role's display label from every function that projects a role to a user-facing surface, and expose invitation cancel/resend through the better-auth adapter.

  **`role_label` on eight functions.** `core.roles` carries both a stable identifier (`name`) and a display label (`description`), but every read function returned only the identifier, so consumers rendered `operator` and `general_manager` to end users — including on the invitation landing page, the first thing an invited user ever sees.

  Deriving the label from the identifier is wrong and quietly so: `super_admin`'s label is `Owner`, so de-slugifying yields "Super Admin", a role that does not exist in the product and the highest-privilege one in the system. `public.list_organization_members` is the function that renders an organization's owner, which makes it the most affected of the eight.

  `role_label` is now returned by `list_invitations`, `get_invitation_details`, `list_organization_members`, `list_my_organizations`, `get_user_organizations`, `list_unit_members`, `list_my_units`, and `get_user_units` — and by the `core.*` functions behind the first two.

  The label is emitted raw, so `role_label` is **nullable**: `core.roles.description` has no `NOT NULL` constraint and roles are seeded per deployment, so `NULL` genuinely means "this deployment gave the role no label". It is deliberately not coalesced to the identifier, which would render `super_admin` to an end user in exactly the case nobody tests. Render `role_label ?? role_name`.

  Purely additive — the existing `role` / `role_name` columns are unchanged, and the `role` vs `role_name` naming inconsistency across these functions is deliberately left alone, since renaming would break every consumer selecting by name.

  `@smta/schemas` types the new key as required and nullable (`z.string().nullable()`). All `@smta/*` packages publish at the same version, so a database missing the column is a deploy error and should raise at the first call rather than silently render a blank label.

  **Invitation cancel and resend.** `public.cancel_invitation` and `public.resend_invitation` have always existed but were unreachable from the adapter, so an application could create and list invitations but never cancel or resend one — an invitation to a typo'd address was permanent until it expired.

  - `POST /smta/invitation/:id/cancel` → `{ success: true }`
  - `POST /smta/invitation/:id/resend` → `[{ id, token, email, expires_at }]`

  Both are `sessionMiddleware`-guarded; the SQL layer enforces organization membership, not role-based permission — `core.cancel_invitation` requires the inviter or any org member, and `core.resend_invitation` requires only org membership. Consumers who want these restricted to admins or the original inviter must apply their own CASL check in the application layer. **The resend response carries an invitation token** — `resend_invitation` mints a fresh one so the caller can re-send the email. Unlike `list_invitations`, which deliberately never re-exposes tokens, this response is a secret: do not log or persist it.

  `@smta/schemas` gains the matching contracts: `cancelInvitationInputSchema`, `resendInvitationInputSchema`, and `resendInvitationResponseSchema` (aliased to `invitationResponseSchema`, since `resend_invitation` returns exactly `create_invitation`'s shape). `cancel_invitation` returns `void` and so has no output schema — the adapter's `{ success: true }` is an HTTP-layer contract, not a `public.*` one.

  **Applying this release:** re-apply exactly these five files, **in one transaction**, in this order (the `packages/core/sql-scripts.json` order):

  ```
  sql/functions/invitations.sql
  sql/public/functions/user_profile.sql
  sql/public/functions/organizations.sql
  sql/public/functions/units.sql
  sql/public/functions/invitations.sql
  ```

  Do not re-run the full script list — `@smta/core` ships raw SQL with no migration mechanism, and tables are declared with bare `CREATE TABLE` (no `IF NOT EXISTS`), so replaying every script against a live database fails on the first table. A single transaction matters because `public.get_user_organizations` delegates to `public.list_my_organizations` via `SELECT *`: `user_profile.sql` is applied before `organizations.sql`, so between those two files the delegator has the new 5-column shape while the delegate still has the old 4-column one, and every call to `get_user_organizations` in that window raises a structure mismatch. On a fresh install this window doesn't exist; on a live re-apply it's a real (if brief) outage if not wrapped in one transaction.

  Because these functions are dropped and recreated rather than replaced in place, `public.get_invitation_details` is `SECURITY DEFINER` and its owner becomes whichever role applies the SQL — apply as the same role that owns the existing functions (the docs already say to run migrations as a role inheriting `app_admin`). For a definer function the owner is the privilege boundary, so this is not cosmetic.

  Upgrading the npm packages without re-running the SQL will raise a `ZodError` naming `role_label`.

## 0.6.2

### Patch Changes

- 6e273f9: Expose the `list_invitations` status filter, and reject invalid status values instead of returning an empty set.

  `public.list_invitations` has always accepted `p_status`, but the better-auth adapter never passed it, so `smtaListInvitations` returned invitations of every status and consumers had to filter client-side.

  - `core.list_organization_invitations` now validates `p_status`. A `NULL` (or omitted) value still returns every status; anything outside `'pending' | 'accepted' | 'expired' | 'cancelled'` raises `Invalid status. Must be "pending", "accepted", "expired", or "cancelled".` The filter is an exact match, so previously a typo like `'PENDING'` returned zero rows — indistinguishable from "this organization has no invitations". Validation runs _after_ the membership check, so a non-member cannot use the error to probe accepted values.
  - `smtaListInvitations` accepts an optional `?status=` query parameter, and the `listInvitations` handler takes an optional third `status` argument.

  The accepted values are deliberately **not** duplicated in TypeScript. The adapter forwards `status` opaquely, so SQL remains the single source of truth and adding a status there needs no adapter release.

  Backward compatible: the handler's new parameter is optional, and a request without `?status=` behaves exactly as before. The one behavior change is that an invalid status now raises rather than returning an empty result — which also benefits the Supabase and payload adapters and any direct SQL caller, not just better-auth.

## 0.6.1

### Patch Changes

- 3f1ed92: Finish de-Supabasing the core secrets layer and fix plain-Postgres test bootstrap.

  - `platform.tenant_secrets.vault_key_id` (Supabase-Vault-specific `UUID`) is renamed to a neutral `secret_ref` (`TEXT`), matching the opaque `core.store_secret_impl()` contract. The core secret functions and the `clean-up-database.sql` maintenance script are updated; the Supabase adapter (vault UUID), better-auth and payload (pgcrypto) providers all store their reference unchanged in the new column.
  - Removed remaining Supabase/Vault wording from `@smta/core` comments and stub messages (`get_current_user_id`, public `secrets`/`invitations` RPC examples, `organization_files`, `billing`, platform `grants`) so core schemas no longer name any adapter.
  - Fixed the plain-Postgres pgTap bootstrap ordering: split the role/`"user"`-table prerequisites into `tests/fixtures/00a_plain_pg_prereqs.sql` (loaded before `00_test_helpers.sql`) and left the `test_helpers.*` overrides in `00b_plain_pg_shim.sql` (loaded after). A cold cluster now passes 506/506 on its first `SMTA_TARGET=plain` run.

  No behavior change on Supabase. The better-auth/payload generated SQL continues to load on vanilla PostgreSQL 18 with zero errors and no Supabase prerequisites.

## 0.6.0

### Minor Changes

- c6b36db: De-Supabase `@smta/core`: core is now adapter-agnostic and loads standalone on vanilla PostgreSQL 18.

  - Core owns two neutral roles, `app_user` (RLS-subject) and `app_admin` (BYPASSRLS); `core.get_current_user_id()` (reading `app.current_user_id`) replaces `auth.uid()` everywhere, and all `auth.*` references are removed from core.
  - Supabase adapter restores its deltas — maps `authenticated`→`app_user` / `service_role`→`app_admin`, re-adds the `auth.users` FKs and signup trigger, owns the `pg_graphql` disable, and provides the Vault `read_secret_impl`. Behavior is unchanged on Supabase.
  - better-auth and payload adapters gain a pgcrypto secrets implementation (keyed off the `app.secrets_key` GUC) and neutral-role wiring.
  - A plain-Postgres load gate plus CI workflow guard against regressions; the pgTap suite runs on vanilla Postgres via `SMTA_TARGET=plain`.

  BREAKING: `@smta/cli` now requires `--better-auth-ids <uuid|mapped>` when `--adapter better-auth`. BREAKING: `platform.platform_users.supabase_user_id` is renamed to `user_id`.

## 0.5.1

## 0.5.0

### Minor Changes

- df83bbf: Updated Better-Auth Implementation

## 0.4.0

### Minor Changes

- 66f9226: Linter Review Fixes

## 0.3.0

### Minor Changes

- f386f14: Addressed GraphQL and core Schema RLS

## 0.2.0

### Minor Changes

- 4f3cec7: Added README files for npm metadata
