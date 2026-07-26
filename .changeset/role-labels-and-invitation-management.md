---
"@smta/core": minor
"@smta/schemas": minor
"@smta/better-auth": minor
---

Return the role's display label from every function that projects a role to a user-facing surface, and expose invitation cancel/resend through the better-auth adapter.

**`role_label` on eight functions.** `core.roles` carries both a stable identifier (`name`) and a display label (`description`), but every read function returned only the identifier, so consumers rendered `operator` and `general_manager` to end users — including on the invitation landing page, the first thing an invited user ever sees.

Deriving the label from the identifier is wrong and quietly so: `super_admin`'s label is `Owner`, so de-slugifying yields "Super Admin", a role that does not exist in the product and the highest-privilege one in the system. `public.list_organization_members` is the function that renders an organization's owner, which makes it the most affected of the eight.

`role_label` is now returned by `list_invitations`, `get_invitation_details`, `list_organization_members`, `list_my_organizations`, `get_user_organizations`, `list_unit_members`, `list_my_units`, and `get_user_units` — and by the `core.*` functions behind the first two.

The label is emitted raw, so `role_label` is **nullable**: `core.roles.description` has no `NOT NULL` constraint and roles are seeded per deployment, so `NULL` genuinely means "this deployment gave the role no label". It is deliberately not coalesced to the identifier, which would render `super_admin` to an end user in exactly the case nobody tests. Render `role_label ?? role_name`.

Purely additive — the existing `role` / `role_name` columns are unchanged, and the `role` vs `role_name` naming inconsistency across these functions is deliberately left alone, since renaming would break every consumer selecting by name.

`@smta/schemas` types the new key as required and nullable (`z.string().nullable()`). All `@smta/*` packages publish at the same version, so a database missing the column is a deploy error and should raise at the first call rather than silently render a blank label.

**Invitation cancel and resend.** `public.cancel_invitation` and `public.resend_invitation` have always existed but were unreachable from the adapter, so an application could create and list invitations but never cancel or resend one — an invitation to a typo'd address was permanent until it expired.

- `POST /smta/invitation/:id/cancel` → `{ success: true }`
- `POST /smta/invitation/:id/resend` → `[{ id, token, email, expires_at }]`

Both are `sessionMiddleware`-guarded, with the SQL functions doing their own authorization on top. **The resend response carries an invitation token** — `resend_invitation` mints a fresh one so the caller can re-send the email. Unlike `list_invitations`, which deliberately never re-exposes tokens, this response is a secret: do not log or persist it.

**Applying this release:** the SQL must be re-applied. Adding a column to a `RETURNS TABLE` requires dropping and recreating the function, which the shipped SQL does inline. Upgrading the npm packages without re-running the SQL will raise a `ZodError` naming `role_label`.
