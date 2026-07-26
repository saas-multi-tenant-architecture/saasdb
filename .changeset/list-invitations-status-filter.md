---
"@smta/core": patch
"@smta/better-auth": patch
---

Expose the `list_invitations` status filter, and reject invalid status values instead of returning an empty set.

`public.list_invitations` has always accepted `p_status`, but the better-auth adapter never passed it, so `smtaListInvitations` returned invitations of every status and consumers had to filter client-side.

- `core.list_organization_invitations` now validates `p_status`. A `NULL` (or omitted) value still returns every status; anything outside `'pending' | 'accepted' | 'expired' | 'cancelled'` raises `Invalid status. Must be "pending", "accepted", "expired", or "cancelled".` The filter is an exact match, so previously a typo like `'PENDING'` returned zero rows — indistinguishable from "this organization has no invitations". Validation runs *after* the membership check, so a non-member cannot use the error to probe accepted values.
- `smtaListInvitations` accepts an optional `?status=` query parameter, and the `listInvitations` handler takes an optional third `status` argument.

The accepted values are deliberately **not** duplicated in TypeScript. The adapter forwards `status` opaquely, so SQL remains the single source of truth and adding a status there needs no adapter release.

Backward compatible: the handler's new parameter is optional, and a request without `?status=` behaves exactly as before. The one behavior change is that an invalid status now raises rather than returning an empty result — which also benefits the Supabase and payload adapters and any direct SQL caller, not just better-auth.
