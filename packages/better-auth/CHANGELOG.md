# @smta/better-auth

## 0.6.1

### Patch Changes

- fa6c5d0: Finish de-Supabasing the core secrets layer and fix plain-Postgres test bootstrap.

  - `platform.tenant_secrets.vault_key_id` (Supabase-Vault-specific `UUID`) is renamed to a neutral `secret_ref` (`TEXT`), matching the opaque `core.store_secret_impl()` contract. The core secret functions and the `clean-up-database.sql` maintenance script are updated; the Supabase adapter (vault UUID), better-auth and payload (pgcrypto) providers all store their reference unchanged in the new column.
  - Removed remaining Supabase/Vault wording from `@smta/core` comments and stub messages (`get_current_user_id`, public `secrets`/`invitations` RPC examples, `organization_files`, `billing`, platform `grants`) so core schemas no longer name any adapter.
  - Fixed the plain-Postgres pgTap bootstrap ordering: split the role/`"user"`-table prerequisites into `tests/fixtures/00a_plain_pg_prereqs.sql` (loaded before `00_test_helpers.sql`) and left the `test_helpers.*` overrides in `00b_plain_pg_shim.sql` (loaded after). A cold cluster now passes 506/506 on its first `SMTA_TARGET=plain` run.

  No behavior change on Supabase. The better-auth/payload generated SQL continues to load on vanilla PostgreSQL 18 with zero errors and no Supabase prerequisites.

## 0.6.0

## 0.5.1

## 0.5.0

### Minor Changes

- df83bbf: Updated Better-Auth Implementation

## 0.1.1

### Patch Changes

- 41b43f6: Added Better-Auth Adapter
