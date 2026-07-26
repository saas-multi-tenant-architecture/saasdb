# Bug report — `@smta/better-auth`: `createInvitation` passes arguments in the wrong order

**Package:** `@smta/better-auth@0.6.1` (better-auth adapter)
**Severity:** Blocking — invitation creation fails 100% of the time. No workaround short of bypassing the handler.
**Found:** 2026-07-26, integrating the invitation flow in another project that implements SMTA & Better-Auth.

---

## 1. The defect

`dist/plugin/endpoints.js:36` (source: the `createInvitation` handler in `plugin/endpoints.ts`):

```js
async createInvitation(userId, orgId, email, roleId) {
    return withSMTA(pool, userId, (client) =>
        callPublicFn(client, 'public.create_invitation', [orgId, email, roleId]));
}
```

The helper binds those **positionally** (`dist/plugin/endpoints.js:14-19`):

```js
async function callPublicFn(client, fnName, args) {
    const placeholders = args.map((_, i) => `$${i + 1}`).join(', ');
    const sql = `SELECT * FROM ${fnName}(${placeholders})`;
    const result = await client.query(sql, args);
    return result.rows;
}
```

But the SQL function's parameter order is **email first**:

```
create_invitation(
  p_email           text,
  p_organization_id uuid,
  p_role_id         uuid,
  p_unit_id         uuid  DEFAULT NULL,
  p_metadata        jsonb DEFAULT '{}'
)
```

So arguments 1 and 2 are transposed:

| Placeholder | Handler sends | Function expects | Result |
|---|---|---|---|
| `$1` | `orgId` (uuid) | `p_email` **text** | Silently accepted — a uuid is valid text |
| `$2` | `email` (text) | `p_organization_id` **uuid** | **Cast failure** |
| `$3` | `roleId` (uuid) | `p_role_id` uuid | Fine |

The first argument is the reason this is easy to miss: passing a uuid into a `text` parameter raises nothing, so the failure surfaces one argument later and looks like a caller problem rather than an ordering problem.

## 2. Reproduction

```sql
BEGIN;
-- exactly what the adapter sends
SELECT * FROM public.create_invitation(
  '00000000-0000-0000-0000-0000000000aa',   -- $1 orgId  -> p_email (text)
  'operator@example.com',                    -- $2 email  -> p_organization_id (uuid)
  '00000000-0000-0000-0000-0000000000bb'     -- $3 roleId -> p_role_id (uuid)
);
ROLLBACK;
```

```
ERROR:  invalid input syntax for type uuid: "operator@example.com"
```

SQLSTATE `22P02` (`invalid_text_representation`). It fails at argument binding, before the function body runs, so nothing is ever written.

## 3. Blast radius — only this one handler

I audited all nine `callPublicFn` call sites in `dist/plugin/endpoints.js` against the live signatures in `pg_proc`. **`createInvitation` is the only mismatch.**

| Handler | Sends | Signature | |
|---|---|---|---|
| `createOrganization` | `[name, description ?? null]` | `(p_name text, p_description text DEFAULT NULL)` | ✅ |
| `listOrganizations` | `[]` → `list_my_organizations` | *(no args)* | ✅ |
| `getOrganization` | `[orgId]` | `(p_id uuid)` | ✅ |
| **`createInvitation`** | **`[orgId, email, roleId]`** | **`(p_email text, p_organization_id uuid, p_role_id uuid, …)`** | ❌ |
| `acceptInvitation` | `[token]` | `(p_token text)` | ✅ |
| `getInvitationDetails` | `[token]` | `(p_token text)` | ✅ |
| `listInvitations` | `[orgId]` | `(p_organization_id uuid, p_status text DEFAULT NULL)` | ✅ (see §6) |
| `listOrgMembers` | `[orgId]` → `list_organization_members` | `(p_id uuid)` | ✅ |
| `getUserPermissions` | `[orgId]` | `(p_org_id uuid)` | ✅ |

## 4. Why nothing caught it

The handler's TypeScript signature is `createInvitation(userId, orgId, email, roleId)` — all four parameters are `string`, so **the type system cannot detect the transposition**. Any consumer test that mocks the endpoint (which is the natural thing to do, since the real call needs a database) passes happily. It only fails against a live Postgres.

In our case every test mocked it and the whole feature shipped green through thirteen task reviews; the bug surfaced only when we attempted one real-database integration test.

## 5. Recommended fix

**Immediate — one line** in `plugin/endpoints.ts`:

```ts
callPublicFn(client, 'public.create_invitation', [email, orgId, roleId])
```

**Systemic — make this class of bug impossible.** Positional binding is the underlying hazard: it silently transposes whenever the swapped types happen to be compatible, and it will break again if a parameter is ever inserted into the middle of a SQL function's signature. Postgres supports named notation, so `callPublicFn` could bind by name:

```ts
async function callPublicFn(client, fnName, args: Record<string, unknown>) {
  const names = Object.keys(args);
  const placeholders = names.map((n, i) => `${n} := $${i + 1}`).join(', ');
  const sql = `SELECT * FROM ${fnName}(${placeholders})`;
  const result = await client.query(sql, Object.values(args));
  return result.rows;
}
```

Called as `callPublicFn(client, 'public.create_invitation', { p_email: email, p_organization_id: orgId, p_role_id: roleId })`. A wrong name then fails loudly and immediately (`function ... does not exist`) instead of silently mis-binding, and adding an optional parameter to a SQL function can never shift existing call sites.

**Test that would have caught it:** one integration test per handler that calls it against a real database and asserts a row comes back. Type-level and mocked tests structurally cannot catch an argument transposition between same-typed parameters.

## 6. Secondary observation (not a bug)

`list_invitations` accepts `p_status text DEFAULT NULL`, but the `listInvitations` handler passes only `orgId`, so it always returns invitations of **every** status. Consumers wanting just pending invitations must filter client-side. If exposing that parameter fits the adapter's scope, it would save every consumer the same workaround.

## 7. Verification after the fix

```sql
select p.proname, pg_get_function_arguments(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_invitation';
```

Then create an invitation through the adapter against a live database and confirm a row returns with a non-null `token`.

---

**Note on scope:** this is entirely within SMTA's tenant-division responsibility — invitation records and org membership. It does not touch better-auth's authentication concerns. The `smtaAcceptInvitation` endpoint's use of better-auth `sessionMiddleware` for identity is correct and unaffected.
