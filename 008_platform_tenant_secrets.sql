-- 008_platform_tenant_secrets.sql
-- Purpose: Define secure storage reference table for tenant secrets using Supabase Vault

-- ========================================
-- TABLE: platform.tenant_secrets
-- ========================================
CREATE TABLE platform.tenant_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  scope TEXT NOT NULL CHECK (scope IN ('organization', 'user')),
  organization_id UUID REFERENCES core.organizations(id),
  user_id UUID REFERENCES auth.users(id),

  secret_name TEXT NOT NULL, -- e.g., 'smtp_password', 'api_key'
  vault_key_id UUID NOT NULL, -- Supabase Vault secret key reference

  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID,
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,

  CHECK (
    (scope = 'organization' AND organization_id IS NOT NULL AND user_id IS NULL) OR
    (scope = 'user' AND user_id IS NOT NULL AND organization_id IS NULL)
  )
);

-- ========================================
-- NOTES
-- ========================================
-- - The secret value is never stored in this table
-- - It is managed via Supabase Vault and referenced via vault_key_id
-- - Only the service role should access or write this table directly
-- - RLS policies are deferred until the dedicated security stage
