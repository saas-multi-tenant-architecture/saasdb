# @smta/better-auth

## 0.6.2

### Patch Changes

- c164fb0: Fix `createInvitation` passing arguments to `public.create_invitation()` in the wrong order.

  The `createInvitation` handler bound `[orgId, email, roleId]` positionally, but the SQL function takes email first — `create_invitation(p_email TEXT, p_organization_id UUID, p_role_id UUID, ...)`. Arguments 1 and 2 were transposed, so every invitation creation failed against a real database with `invalid input syntax for type uuid` (SQLSTATE `22P02`). The failure happened during argument binding, before the function body ran, so nothing was ever written.

  The transposition was invisible to the type system because all four handler parameters are `string`, and invisible to mocked tests because the mis-binding only surfaces against live PostgreSQL. Passing a uuid into a `text` parameter raises nothing, so the error appeared one argument later and looked like a caller problem rather than an ordering problem.

  - `createInvitation` now sends `[email, orgId, roleId]`, matching the SQL signature.
  - Added `tests/adapters/04_endpoint_arg_order.sh`, which checks every `callPublicFn()` call site in the adapter against the live signature in `pg_proc` and fails on any transposition. All nine call sites were audited; `createInvitation` was the only mismatch.
  - `scripts/run_tests.sh` now executes the `tests/adapters/*.sh` guards as part of the suite. They previously existed but were never run by the test runner or CI.
  - Corrected the `SYNC-CHECK` reference comments in `@smta/schemas` for `create_invitation` and `list_invitations`, which documented the org parameter as `p_org_id` when the actual name is `p_organization_id`.

  No SQL changes — the database function and the published RPC reference documentation were already correct; only the adapter's call disagreed with them.

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

## 0.5.1

## 0.5.0

### Minor Changes

- df83bbf: Updated Better-Auth Implementation

## 0.1.1

### Patch Changes

- 41b43f6: Added Better-Auth Adapter
