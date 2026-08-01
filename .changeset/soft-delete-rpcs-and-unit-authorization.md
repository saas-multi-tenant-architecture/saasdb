---
"@smta/core": minor
---

Fix three soft-delete RPCs that could never succeed, and close an unauthorized cross-tenant delete in `delete_unit`.

**Three RPCs were unreachable for every caller.** `remove_user_from_unit`, `remove_user_from_organization` and `delete_file` were `SECURITY INVOKER`. When an `UPDATE` needs read access to the table — any `WHERE` clause referencing a column — PostgreSQL also checks the `SELECT` policy against the post-update row, so a caller cannot update a row into a state they could not see. Every SMTA entity table's `SELECT` policy filters `is_deleted = false`, so setting the flag produced a row that failed that check and the write was refused with `new row violates row-level security policy`. This was unconditional: it failed for an org super_admin acting on a row plainly visible to them. All three are now `SECURITY DEFINER` and enforce, in their own bodies, exactly the authorization their RLS policies previously expressed — membership of the owning organization, no super_admin required. The `protect_super_admin` trigger still guards the organization owner.

Widening the `UPDATE` policy's `WITH CHECK` would not have helped; the `UPDATE` policy was never what rejected the row.

**`delete_unit` performed no authorization check at all.** It was `SECURITY DEFINER` — so RLS did not apply — and validated only that its argument was non-null. Any authenticated user could soft-delete any organization's unit and cascade-delete every membership in it, without being a member of that organization and without being able to see the unit. Unit ids are returned by `list_units`, `list_my_units` and `get_unit`, so no guessing was required. It now resolves the owning organization and requires the caller to be its super_admin, matching `add_member_to_unit`, `remove_member_from_unit` and `delete_organization`. Callers outside the organization get `Unit not found` rather than a message confirming the unit exists.

**`assign_user_to_unit` could not re-add a removed member.** `core.unit_memberships` has a unique constraint on `(user_id, unit_id)` that a soft-deleted row still occupies, and the function performed a bare `INSERT`. Moving a person between units and back failed permanently with a duplicate key error. It now reactivates the existing row, as `add_member_to_unit` already did. Reactivation targets a row the caller cannot see, so this function is now `SECURITY DEFINER` as well.

**`assign_user_to_unit` accepted a user from another organization.** Its RLS only constrained the caller, never the target, so any org member could attach an arbitrary user id — including one belonging to another tenant — to a unit in their own organization, making `core.is_unit_member` true for a stranger. It now requires the target to be a member of the organization that owns the unit, the same guard `add_member_to_unit` already carried.

All four functions were also added to `grants.sql` with `REVOKE EXECUTE ... FROM PUBLIC`, matching the file's existing policy for authenticated `SECURITY DEFINER` functions.

### Behaviour changes to check before upgrading

- `delete_unit` now requires super_admin. Callers who relied on it working for ordinary org members will get `Only a super_admin can delete a unit`.
- `assign_user_to_unit` now rejects a target who is not a member of the owning organization with `User is not a member of the organization`.
- `remove_user_from_unit`, `remove_user_from_organization` and `delete_file` now raise `Member not found` / `File not found` instead of silently affecting nothing. Previously they always raised an RLS error, so no working call site can depend on the old behaviour.

### Upgrading

Re-apply these files in a single transaction:

```
packages/core/sql/public/functions/units.sql
packages/core/sql/public/functions/organizations.sql
packages/core/sql/public/functions/files.sql
packages/core/sql/public/grants.sql
```

No table, policy or signature changed, so no data migration is required.
