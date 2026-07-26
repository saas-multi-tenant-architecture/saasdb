---
"@smta/better-auth": patch
---

Fix `createInvitation` passing arguments to `public.create_invitation()` in the wrong order.

The `createInvitation` handler bound `[orgId, email, roleId]` positionally, but the SQL function takes email first — `create_invitation(p_email TEXT, p_organization_id UUID, p_role_id UUID, ...)`. Arguments 1 and 2 were transposed, so every invitation creation failed against a real database with `invalid input syntax for type uuid` (SQLSTATE `22P02`). The failure happened during argument binding, before the function body ran, so nothing was ever written.

The transposition was invisible to the type system because all four handler parameters are `string`, and invisible to mocked tests because the mis-binding only surfaces against live PostgreSQL. Passing a uuid into a `text` parameter raises nothing, so the error appeared one argument later and looked like a caller problem rather than an ordering problem.

- `createInvitation` now sends `[email, orgId, roleId]`, matching the SQL signature.
- Added `tests/adapters/04_endpoint_arg_order.sh`, which checks every `callPublicFn()` call site in the adapter against the live signature in `pg_proc` and fails on any transposition. All nine call sites were audited; `createInvitation` was the only mismatch.
- `scripts/run_tests.sh` now executes the `tests/adapters/*.sh` guards as part of the suite. They previously existed but were never run by the test runner or CI.
- Corrected the `SYNC-CHECK` reference comments in `@smta/schemas` for `create_invitation` and `list_invitations`, which documented the org parameter as `p_org_id` when the actual name is `p_organization_id`.

No SQL changes — the database function and the published RPC reference documentation were already correct; only the adapter's call disagreed with them.
