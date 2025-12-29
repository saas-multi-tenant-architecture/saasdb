# Secrets Functions Moved

## Change Summary

The tenant secret management functions were moved from `platform` schema to `core` schema.

**Original location:** `sql/_platform/functions/secrets.sql` (archived as `secrets.sql.old`)
**New locations:**
- `sql/_core/functions/secrets.sql` - Core implementation with SECURITY DEFINER
- `sql/_public/functions/secrets.sql` - Public RPC wrappers

## Reason for Move

1. **Schema Access Issue**: `authenticated` role was REVOKED from `platform` schema, preventing tenant users from calling these functions even with SECURITY INVOKER
2. **Architectural Alignment**: Tenant secret management is a tenant-level operation, not platform admin operation
3. **Proper Isolation**: Platform schema should remain strictly for SaaS operator admin functions

## What Changed

### Fixed Bugs
- Fixed undefined variable `p_user_id` → changed to `auth.uid()`
- Fixed `delete_tenant_secret()` to fetch secret details before authorization check
- Fixed vault deletion to use `vault_key_id` instead of `secret_id`
- Changed to `SECURITY DEFINER` to access `platform.tenant_secrets` and `vault.secrets`

### New Functions
- Added `core.list_tenant_secrets()` for retrieving secret metadata
- Created public RPC wrappers: `public.create_secret()`, `public.delete_secret()`, `public.list_secrets()`

## Usage

Tenant users call these via Supabase RPC:

```javascript
// Create organization secret
const { data, error } = await supabase.rpc('create_secret', {
  p_scope: 'organization',
  p_id: organizationId,
  p_name: 'SMTP Password',
  p_secret: 'my-secret-value'
})

// List secrets
const { data } = await supabase.rpc('list_secrets', {
  p_scope: 'organization',
  p_id: organizationId
})

// Delete secret
await supabase.rpc('delete_secret', {
  p_secret_id: secretId
})
```

## Security Model

- Functions use `SECURITY DEFINER` to access restricted tables/schemas
- Authorization enforced within function body using `auth.uid()`
- Organization secrets: only `super_admin` can create/delete
- User secrets: only the owning user can create/delete
- Secret values NEVER returned to client (only metadata)
