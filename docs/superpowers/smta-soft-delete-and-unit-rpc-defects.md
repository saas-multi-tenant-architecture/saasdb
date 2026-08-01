# SMTA: three unreachable soft-delete RPCs, and four defects in the units surface

**Date:** 2026-08-01
**Reported from:** HelmetFires, during design of the Sites and Units slice.
**Verified against:** the HelmetFires database (Postgres 18, SMTA `core`/`public` as generated),
acting as the application login role `helmetfires_app` with `app.current_user_id` and
`app.current_org_id` pinned, every check inside a rolled-back transaction.
**Source reviewed:** `saasdb/packages/core/sql/public/functions/units.sql`,
`organizations.sql`, `files.sql`, and `saasdb/tests/`.

Nothing in SMTA was edited. This document is a report plus proposed fixes.

---

## TL;DR

Two independent problems, one of which is a class rather than a single bug.

1. **Three documented RPCs can never succeed for any caller.** `remove_user_from_unit`,
   `remove_user_from_organization` and `delete_file` are `SECURITY INVOKER` functions that
   perform a soft delete on a table whose `SELECT` policy filters `is_deleted = false`.
   Postgres requires the post-update row to satisfy the `SELECT` policy, so flipping the flag
   makes the row invisible to its own writer and the write is refused. This is unconditional:
   it fails for an organization super_admin on a row that is plainly visible to them.

2. **`delete_unit` performs no authorization check whatsoever.** It is `SECURITY DEFINER`, so
   RLS does not apply, and it validates only that its argument is not null. A user with no
   membership in an organization can soft-delete that organization's unit and cascade-delete
   every membership in it.

Plus two smaller defects in `assign_user_to_unit`: it cannot re-add a previously removed member,
and it does not verify that the target user belongs to the organization.

| # | Function | Defect | Severity |
|---|---|---|---|
| 1 | `remove_user_from_unit` | Unreachable: RLS refuses the soft delete | Critical |
| 1 | `remove_user_from_organization` | Unreachable: RLS refuses the soft delete | Critical |
| 1 | `delete_file` | Unreachable: RLS refuses the soft delete | Critical |
| 2 | `delete_unit` | `DEFINER` with no authorization check, cross-tenant | Critical |
| 3 | `assign_user_to_unit` | Cannot re-add a removed member, unique violation | High |
| 4 | `assign_user_to_unit` | Accepts a user who is not an organization member | High |

---

## Finding 1: three soft-delete RPCs are unreachable

### The mechanism

For an `UPDATE`, Postgres checks the update policy's `USING` clause against the old row and its
`WITH CHECK` clause against the new row. When the table also carries a `SELECT` policy, the new
row must satisfy that too, so that a caller cannot update a row into a state they could not see.

SMTA generates, on almost every `core` table:

- soft-delete columns `is_deleted` / `deleted_at` / `deleted_by`
- a `SELECT` policy whose predicate begins `is_deleted = false`
- an `UPDATE` policy whose `WITH CHECK` never mentions `is_deleted`

Setting `is_deleted = true` therefore produces a row that fails the `SELECT` policy, and the
write is refused. The `UPDATE` policy is not the cause and widening it would not help.

**This affects 9 of the 11 `core` tables.** Only `core.audit_logs` and `core.users_meta` have a
`SELECT` policy that does not filter `is_deleted`, and both soft-delete without complaint.

### The natural experiment

Identical policy structure, differing only in whether the `SELECT` policy filters the flag:

```sql
-- core.units: SELECT policy filters is_deleted
update core.units      set is_deleted = true  -- ERROR: new row violates RLS policy
update core.units      set deleted_at = now() -- OK
update core.units      set name = 'renamed'   -- OK

-- core.users_meta: SELECT policy does NOT filter is_deleted
update core.users_meta set is_deleted = true  -- OK
```

The `deleted_at` line is the control that rules out the update path itself being blocked.

### The three functions this breaks

All three are `SECURITY INVOKER`, so they inherit the caller's RLS.

```
public.remove_user_from_unit(p_user_id, p_unit_id)          -> core.unit_memberships
public.remove_user_from_organization(p_user_id, p_org_id)   -> core.memberships
public.delete_file(p_file_id)                               -> core.organization_files
```

Reproduced acting as a genuine organization super_admin, with the target row confirmed visible
first, so neither authorization nor a zero-row match explains the failure:

```
acting as super_admin: true
target membership visible: 1

select public.remove_user_from_organization(...)
ERROR:  new row violates row-level security policy for table "memberships"
CONTEXT: SQL statement "UPDATE core.memberships SET is_deleted = true, ..."
         PL/pgSQL function remove_user_from_organization(uuid,uuid) line 4

select public.delete_file(...)
ERROR:  new row violates row-level security policy for table "organization_files"
CONTEXT: SQL statement "UPDATE core.organization_files SET is_deleted = true, ..."
         PL/pgSQL function delete_file(uuid) line 3

select public.remove_user_from_unit(...)
ERROR:  new row violates row-level security policy for table "unit_memberships"
CONTEXT: SQL statement "UPDATE core.unit_memberships SET is_deleted = true, ..."
         PL/pgSQL function remove_user_from_unit(uuid,uuid) line 3
```

**A caution when reproducing this.** An earlier attempt of mine looked like a pass and was
vacuous: the organization had no super_admin, so `app.current_user_id` was empty, the RLS
`USING` clause matched nothing, the `UPDATE` touched zero rows, and no `WITH CHECK` was ever
evaluated. A test written that way is green and proves nothing. Any test for this must assert
that the target row was visible beforehand and that the row count actually changed afterwards.

### Why the equivalents work

The four sibling functions that do the same job succeed only because they are `SECURITY DEFINER`
and so bypass RLS entirely:

| Works (`DEFINER`) | Unreachable (`INVOKER`) |
|---|---|
| `delete_unit` | `remove_user_from_unit` |
| `remove_member_from_unit` | `remove_user_from_organization` |
| `remove_member_from_organization` | `delete_file` |
| `delete_organization` | |

So for units, the **super-admin-only** removal path works and the **non-privileged** one, which
the RPC reference presents as the ordinary route, has no working implementation.

### Why the tests did not catch it

Not a weak harness. `tests/fixtures/00a_plain_pg_prereqs.sql` creates `authenticated` as
`NOLOGIN` with `app_user` granted, so tests genuinely run subject to RLS and would have caught
this. The cause is simpler: **`assign_user_to_unit` and `remove_user_from_unit` have no test
coverage at all.** `tests/functions/03_membership_functions.sql` exercises only the `DEFINER`
pair, `add_member_to_unit` and `remove_member_from_unit`.

### Proposed fix

Two options. The first is preferable.

**Option A, recommended: make the soft delete legal.** Add `WITH CHECK` clauses that permit the
tombstone transition, so `INVOKER` functions keep working and callers keep RLS protection.
The cleanest form is to allow an update whose new row is a tombstone of a row the caller could
see, for example on `core.units`:

```sql
drop policy units_update on core.units;
create policy units_update on core.units
  for update
  using  (is_deleted = false
          and (core.is_org_member(organization_id) or core.is_super_admin(organization_id)))
  with check (core.is_org_member(organization_id) or core.is_super_admin(organization_id));
-- and widen the SELECT policy so a tombstone does not become invisible mid-statement,
-- or add an explicit carve-out for the is_deleted = false -> true transition.
```

Whichever shape is chosen, the invariant to encode is: *a caller who may see a live row may
retire it.* Apply it uniformly to all 9 affected tables rather than case by case, since the
pattern is generated.

**Option B: convert the three functions to `SECURITY DEFINER`** and give each an explicit
authorization check, matching their working siblings. Smaller change, but it moves three more
functions into the category that must hand-roll authorization, which is exactly where finding 2
came from.

---

## Finding 2: `delete_unit` has no authorization check

`public.delete_unit(p_id uuid)` is `SECURITY DEFINER` and its only validation is
`IF p_id IS NULL`. Its two `DEFINER` siblings in the same file, `add_member_to_unit` and
`remove_member_from_unit`, both begin by resolving the organization and calling
`core.is_super_admin`. `delete_unit` does not, and it is the most destructive of the three: it
cascades to `core.unit_memberships`, `core.unit_meta` and `core.units`.

Reproduced across two unrelated organizations:

```
can Org51 SEE the Org52 unit?     false
is Org51 user a member of Org52?  false
select public.delete_unit('<Org52 unit id>')  ->  SUCCEEDED
```

The caller cannot `select` the row, because RLS correctly hides it, yet can destroy it and every
membership attached to it. Unit ids are exposed to clients in `list_units`, `list_my_units` and
`get_unit` responses, so a caller does not need to guess one.

### Proposed fix

Mirror the sibling functions:

```sql
create or replace function public.delete_unit(p_id uuid)
returns void as $$
declare
  v_org_id uuid;
begin
  if p_id is null then
    raise exception 'Unit id is required';
  end if;

  v_org_id := core.get_org_id_for_unit(p_id);
  if v_org_id is null then
    raise exception 'Unit not found';
  end if;

  if not core.is_super_admin(v_org_id) then
    raise exception 'Only a super_admin can delete a unit';
  end if;

  -- existing cascade unchanged
  ...
end;
$$ language plpgsql security definer set search_path = public, core;
```

If deleting a unit should be available below super_admin, use `core.is_org_member(v_org_id)`
instead, but it must not stay unchecked. Worth auditing every other `SECURITY DEFINER` function
in `public` for the same omission at the same time.

---

## Finding 3: `assign_user_to_unit` cannot re-add a removed member

`core.unit_memberships` has a unique constraint on `(user_id, unit_id)`, and a soft-deleted row
still occupies it. `add_member_to_unit` handles this with `on conflict (user_id, unit_id) do
update set ... is_deleted = false`. `assign_user_to_unit` performs a bare `INSERT`.

```
A. assigned, live members = 1
B. removed via remove_member_from_unit, live members = 0
C. re-add via assign_user_to_unit
   ERROR: duplicate key value violates unique constraint "unit_memberships_user_id_unit_id_key"
D. re-add via add_member_to_unit -> SUCCEEDED, live members = 1
```

This is easy to hit in normal use: move a person from one location to another and back, and the
non-privileged path fails permanently with a constraint error rather than anything actionable.

### Proposed fix

Give `assign_user_to_unit` the same upsert as `add_member_to_unit`:

```sql
insert into core.unit_memberships (user_id, unit_id, role_id, created_by, updated_by)
values (p_user_id, p_unit_id, p_role_id, core.get_current_user_id(), core.get_current_user_id())
on conflict (user_id, unit_id) do update
  set role_id    = excluded.role_id,
      is_deleted = false,
      deleted_at = null,
      deleted_by = null,
      updated_by = core.get_current_user_id(),
      updated_at = now();
```

Note this reactivation is itself an `UPDATE` setting `is_deleted = false`, which is the safe
direction and is not blocked by finding 1.

---

## Finding 4: `assign_user_to_unit` accepts a non-member of the organization

The RPC reference describes it as assigning "an org member" to a unit, and
`add_member_to_unit` enforces exactly that with an explicit `core.memberships` lookup.
`assign_user_to_unit` has no such check. Its RLS only constrains the **caller**, via
`unit_memberships_insert`'s `is_org_member_for_unit(unit_id)`, and says nothing about the target.

```
is 52aa a member of Org51?  false
select public.assign_user_to_unit('52aa', '<Org51 unit>', ...)
  -> ACCEPTED a non-org-member
select public.add_member_to_unit('<Org51 unit>', '52aa', ...)
  -> ERROR: User is not a member of the organization
```

So any organization member can attach an arbitrary user id, including one belonging to another
tenant, to a unit in their own organization. The immediate blast radius is limited, because most
downstream predicates also require organization membership, but it writes cross-tenant rows into
`core.unit_memberships` and makes `core.is_unit_member` true for a stranger.

### Proposed fix

Add the same guard `add_member_to_unit` already carries:

```sql
if not exists (
  select 1 from core.memberships
   where user_id = p_user_id
     and organization_id = core.get_org_id_for_unit(p_unit_id)
     and is_deleted = false
) then
  raise exception 'User is not a member of the organization';
end if;
```

---

## Proposed test additions

The findings above are all cheap to pin, and their absence is why they shipped.

1. **A soft-delete round trip per affected table**, asserting the row is visible before, that the
   call succeeds, and that the live count drops. Nine tables, one shape. Must assert the
   before-state, or the test passes vacuously when RLS matches zero rows.
2. **`remove_user_from_unit`, `remove_user_from_organization` and `delete_file`**, currently
   untested, each called as an ordinary member and as a super_admin.
3. **A cross-tenant negative for every `SECURITY DEFINER` function in `public`**: caller from
   organization A, target in organization B, expect a raise. This is the test that would have
   caught finding 2, and it generalises to functions beyond units.
4. **A remove-then-re-add cycle** through both `assign_user_to_unit` and `add_member_to_unit`.
5. **A non-member target** for both assignment functions, expecting a raise from each.

---

## Documentation notes

Two statements on the units RPC reference page do not match the implementation:

- `remove_user_from_unit` is documented as soft-deleting a membership. It cannot succeed.
- `assign_user_to_unit` is documented as assigning "an org member" with "no elevated permissions
  required". It does not check organization membership, and it fails outright if the person was
  ever removed from that unit.

The page's closing "Parameter Order Summary" table, warning that `assign_user_to_unit` and
`add_member_to_unit` swap their first two parameters, is a good catch and worth keeping.

---

## What HelmetFires does in the meantime

Nothing yet. The Sites and Units slice is paused on this report rather than routing around it.
When SMTA is fixed, HelmetFires intends to call `create_unit`, `update_unit`, `list_units`,
`get_unit` and `list_unit_members` directly, and to use the assign and remove pair for member
management so that unit administration is not restricted to super_admin only.

One HelmetFires-specific consequence worth flagging back: `create_unit` does not add its creator
as a member of the new unit, and `core.handle_new_unit` only creates the `unit_meta` row. Whether
that is intended is a design question rather than a defect, but it means a freshly created unit
has no members, and any product whose visibility rules key on `core.is_unit_member` sees an empty
unit until someone is assigned explicitly.
