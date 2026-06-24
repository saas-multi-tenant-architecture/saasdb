# @smta/core

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
