-- secrets.sql
-- Purpose: Public RPC functions for tenant secret management
-- These are thin wrappers around core.* functions for client access

-- ========================================
-- FUNCTION: public.create_secret()
-- ========================================
-- Creates a new tenant secret for an organization or user
--
-- Parameters:
--   p_scope: 'organization' or 'user'
--   p_id: organization_id or user_id (depending on scope)
--   p_name: Human-readable name for the secret (e.g., 'SMTP Password', 'API Key')
--   p_secret: The actual secret value (will be stored in Vault)
--
-- Returns: UUID of the created secret reference
--
-- Examples:
--   -- Create organization SMTP secret
--   SELECT public.create_secret('organization', 'org-uuid', 'SMTP Password', 'secret123');
--
--   -- Create user API key
--   SELECT public.create_secret('user', core.get_current_user_id(), 'OpenAI API Key', 'sk-...');
CREATE OR REPLACE FUNCTION public.create_secret(
  p_scope TEXT,
  p_id UUID,
  p_name TEXT,
  p_secret TEXT
) RETURNS UUID AS $$
BEGIN
  RETURN core.create_tenant_secret(p_scope, p_id, p_name, p_secret);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.delete_secret()
-- ========================================
-- Deletes a tenant secret
-- Soft-deletes the reference, hard-deletes from Vault (cannot be recovered)
--
-- Parameters:
--   p_secret_id: UUID of the secret to delete
--
-- Authorization:
--   - Organization secrets: only super_admin can delete
--   - User secrets: only the owning user can delete
--
-- Example:
--   SELECT public.delete_secret('secret-uuid');
CREATE OR REPLACE FUNCTION public.delete_secret(
  p_secret_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM core.delete_tenant_secret(p_secret_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- FUNCTION: public.list_secrets()
-- ========================================
-- List all secrets accessible to the current user
--
-- Parameters (optional):
--   p_scope: Filter by 'organization' or 'user' (null = all)
--   p_id: Filter by organization_id or user_id (null = all)
--
-- Returns: Table of secret metadata (NOT the actual secret values)
--
-- Examples:
--   -- List all secrets I have access to
--   SELECT * FROM public.list_secrets();
--
--   -- List all secrets for a specific organization
--   SELECT * FROM public.list_secrets('organization', 'org-uuid');
--
--   -- List my user secrets
--   SELECT * FROM public.list_secrets('user', core.get_current_user_id());
CREATE OR REPLACE FUNCTION public.list_secrets(
  p_scope TEXT DEFAULT NULL,
  p_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  scope TEXT,
  organization_id UUID,
  user_id UUID,
  secret_name TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM core.list_tenant_secrets(p_scope, p_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- ========================================
-- NOTES
-- ========================================
-- These public functions are callable via Supabase RPC:
--
--   const { data, error } = await supabase.rpc('create_secret', {
--     p_scope: 'organization',
--     p_id: orgId,
--     p_name: 'SMTP Password',
--     p_secret: 'my-secret-password'
--   })
--
-- Security:
--   - All authorization checks happen in core.* functions
--   - Secrets are stored in Supabase Vault (encrypted at rest)
--   - Secret values are NEVER returned to the client
--   - Only metadata (id, name, timestamps) is accessible
