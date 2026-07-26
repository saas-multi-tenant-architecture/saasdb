# @smta/core

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
