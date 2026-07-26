# SMTA gaps — role labels across the API surface, and invitation management

**Package:** `@smta/better-auth@0.6.2` + the generated `core.*` / `public.*` SQL
**Severity:** Not defects — two coverage gaps. Neither breaks anything that currently works.
**Found:** 2026-07-26, building the `/team` invite surface in HelmetFires.
**Status:** both blocking HelmetFires work, by explicit choice — we opted to fix upstream rather
than work around locally.

---

## Gap 1 — role-projecting reads return the role's identifier, never its label

*(Originally written against the two invitation functions; widened to the full set of eight after
Jeff asked whether the member/org/unit lists needed it too. They do — see "Scope" below.)*

### What's happening

`core.roles` carries both an identifier and a display label:

| `name` | `description` |
|---|---|
| `super_admin` | **Owner** |
| `general_manager` | General Manager |
| `location_manager` | Location Manager |
| `operator` | Operator |

Two read functions surface a role to end users, and both return `name`:

- `core.list_organization_invitations` → `r.name AS role_name`
- `core.get_invitation_by_token` → `r.name AS role_name`

So any consumer rendering these shows raw identifiers. In HelmetFires that produced a pending-invite
row reading `operator` and an invitation landing page reading *"j@test.com invited you as
general_manager"* — the first thing an invited user ever sees.

### Why a consumer can't just fix it locally

The obvious workaround — de-slugify `name` in the UI — is **wrong**, and quietly so.
`super_admin`'s label is `Owner`; prettifying the identifier yields "Super Admin", a role name that
does not exist in the product. Any consumer that derives labels rather than reading them will get
that one wrong, and it is the highest-privilege role in the system.

The second workaround — the consumer joining `core.roles` itself — works (the table is a global
lookup whose RLS policy is just `is_deleted = false`, so it reads unpinned, even anonymously), but
it means every consumer re-implements a join that the function is already doing. Both of these
functions **already join `core.roles`** to get `r.name`; returning the label costs nothing.

### Suggested fix

Add the label to the returned table rather than swapping `name` for it — consumers key behaviour on
the stable identifier and should keep getting it:

```sql
-- core.list_organization_invitations and core.get_invitation_by_token
RETURNS TABLE (..., role_name text, role_label text, ...)
...
  r.name        AS role_name,
  r.description AS role_label,
```

`public.list_invitations` / `public.get_invitation_details` pass the row through unchanged, and
`@smta/better-auth`'s handlers return `result.rows` verbatim, so no adapter change is needed for
this one — it is purely a SQL change.

### ★ Scope: this is not two functions, it is eight

The same trap exists in every function that projects a role to a user-facing surface. Enumerated by
searching `pg_get_functiondef` for references to `core.roles`, then reading each return type — not
assumed:

| Function | Role column today | Renders to |
|---|---|---|
| `public.list_organization_members` | `role text` | member roster |
| `public.list_unit_members` | `role text` | unit roster |
| `public.list_my_organizations` | `role text` | org switcher / picker |
| `public.list_my_units` | `role text` | unit picker |
| `public.get_user_organizations` | `role text` | (sibling of `list_my_organizations`) |
| `public.get_user_units` | `role text` | (sibling of `list_my_units`) |
| `public.list_invitations` | `role_name text` | pending-invite list |
| `public.get_invitation_details` | `role_name text` | invitation landing page |

**`public.get_organization` needs nothing** — it returns organisation fields only and never projects
a role.

**`public.get_user_role` is a different case** — it returns a bare `text`, not a table, so there is no
column to append. Recommend leaving it alone: it reads as an identifier for logic, not display, and
changing its return type would break every caller.

**★ `list_organization_members` is the most important one, more so than the two invitation
functions.** It is the function that renders an organisation's **Owner**, and `super_admin` → "Owner"
is precisely the mapping no consumer can derive. Invitations can never carry `super_admin` at all
(`core.create_invitation` rejects it, since ownership transfer is `public.transfer_super_admin`), so
the invitation functions can only ever mislabel the three lesser roles. A member roster mislabels the
owner of the organisation, to everyone, every time.

**Doing all eight in one release is worth the extra blast radius**, because the alternative is a
mixed contract — consumers having to remember which functions carry a label and which do not — which
is worse than either end state.

### One thing to NOT do while in there

These functions already disagree on the column name: the invitation pair uses `role_name`, the other
six use `role`. Standardising is tempting while touching all of them, but **renaming an existing
column is a breaking change** for every consumer selecting by name. Appending `role_label` is purely
additive and safe. Recommend appending only, and leaving the existing inconsistency alone (or
resolving it in a separate, clearly-flagged major release).

---

## Gap 2 — no adapter endpoint for cancelling or resending an invitation

### What's happening

The SQL layer supports both operations, and both are already exposed on `public`:

```
public.cancel_invitation(p_invitation_id uuid)  -> void
public.resend_invitation(p_invitation_id uuid)  -> TABLE(id, token, email, expires_at)
```

Both are well-built for this. `core.resend_invitation` mints a fresh token, resets `expires_at` to
`now() + 7 days`, flips `expired` back to `pending`, writes an audit row, and **returns the new
token** — everything a consumer needs to re-send the email. `core.cancel_invitation` authorises
against the inviter or org membership, refuses anything not `pending`, and also audits.

But `@smta/better-auth@0.6.2` registers only four invitation endpoints
(`dist/plugin/index.js:32,37,42,46`):

| Endpoint | SQL behind it |
|---|---|
| `smtaCreateInvitation` | `public.create_invitation` |
| `smtaAcceptInvitation` | `public.accept_invitation` |
| `smtaGetInvitationDetails` | `public.get_invitation_details` |
| `smtaListInvitations` | `public.list_invitations` |
| — | `public.cancel_invitation` ❌ |
| — | `public.resend_invitation` ❌ |

The practical effect: an application built on the adapter can create and list invitations but can
never cancel or resend one. An invitation sent to a typo'd address is permanent until it expires,
and a lost invite email cannot be re-sent. For HelmetFires this is the gap between an invite form
and an invite *surface*.

### Suggested fix

Two handlers mirroring the existing ones, both `sessionMiddleware`-guarded like
`smtaCreateInvitation` (the SQL functions do their own authorisation on top):

```ts
async cancelInvitation(userId, invitationId) {
  return withSMTA(pool, userId, (client) =>
    callPublicFn(client, 'public.cancel_invitation', [invitationId]));
},
async resendInvitation(userId, invitationId) {
  return withSMTA(pool, userId, (client) =>
    callPublicFn(client, 'public.resend_invitation', [invitationId]));
},
```

```ts
smtaCancelInvitation: createAuthEndpoint('/smta/invitation/:id/cancel',
  { method: 'POST', use: [sessionMiddleware] }, ...),
smtaResendInvitation: createAuthEndpoint('/smta/invitation/:id/resend',
  { method: 'POST', use: [sessionMiddleware] }, ...),
```

Note for whoever writes these: `resend_invitation` returns a **token**, so unlike
`list_invitations` these responses carry a secret. Worth a comment saying so, since
`list_invitations` deliberately does not re-expose it.

★ And per the `0.6.1` `createInvitation` bug: `callPublicFn` binds **positionally**. Both functions
take a single `uuid`, so there is nothing to transpose here — but each new endpoint deserves one
real-database integration test, because a mocked test structurally cannot catch an argument
mismatch.

---

## What HelmetFires shipped in the meantime

Only the parts that touch neither gap:

- The invite form's role select now reads `core.roles.description` directly (it was already
  querying that table), so the dropdown shows "Operator" / "General Manager" / "Location Manager".
- The default role is now **Operator**, the least-privileged assignable role, instead of whichever
  sorted first alphabetically (which was `general_manager`).
- Choosing a more privileged role shows a warning describing what it grants, derived from each
  role's `casl_rules`.

Still waiting on the gaps above: the pending-invitation list and the invitation landing page still
render raw identifiers (Gap 1), and there is no cancel or resend control (Gap 2).
