-- tenant_secrets.sql
-- Purpose: Secure storage reference table for tenant secrets using Supabase Vault

-- ========================================
-- TABLE: platform.tenant_secrets
-- ========================================
CREATE TABLE platform.tenant_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  scope TEXT NOT NULL CHECK (scope IN ('organization', 'user')),
  organization_id UUID REFERENCES core.organizations(id),
  user_id UUID, -- FK to the adapter's user identity is restored by the supabase adapter (constraints.sql).

  secret_name TEXT NOT NULL, -- e.g., 'smtp_password', 'api_key'
  vault_key_id UUID NOT NULL, -- Supabase Vault secret key reference

  is_active BOOLEAN DEFAULT TRUE,

  -- Audit fields
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CHECK (
    (scope = 'organization' AND organization_id IS NOT NULL AND user_id IS NULL) OR
    (scope = 'user' AND user_id IS NOT NULL AND organization_id IS NULL)
  )
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_tenant_secrets_organization_id ON platform.tenant_secrets (organization_id) WHERE scope = 'organization';
CREATE INDEX idx_tenant_secrets_user_id ON platform.tenant_secrets (user_id) WHERE scope = 'user';
CREATE INDEX idx_tenant_secrets_scope ON platform.tenant_secrets (scope);

-- ========================================
-- TRIGGERS
-- ========================================
CREATE TRIGGER trg_tenant_secrets_updated
BEFORE UPDATE ON platform.tenant_secrets
FOR EACH ROW EXECUTE FUNCTION utils.update_timestamp();

-- ========================================
-- NOTES
-- ========================================
-- - The secret value is never stored in this table
-- - It is managed via Supabase Vault and referenced via vault_key_id
-- - Only the service role should access or write this table directly
-- - RLS policies are deferred until the dedicated security stage
