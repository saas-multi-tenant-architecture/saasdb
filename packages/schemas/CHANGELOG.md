# @smta/schemas

## 0.8.0

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

## 0.6.1

## 0.6.0

## 0.5.1

## 0.5.0

### Minor Changes

- df83bbf: Updated Better-Auth Implementation

## 0.4.0

## 0.3.0

## 0.2.0

### Minor Changes

- 4f3cec7: Added README files for npm metadata
