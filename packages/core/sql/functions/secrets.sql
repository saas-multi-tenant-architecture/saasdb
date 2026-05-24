-- secrets.sql
-- Purpose: Core functions for tenant secret management (organization and user scoped)

-- ========================================
-- FUNCTION: core.create_tenant_secret()
-- ========================================
-- Creates a new tenant secret for an organization or user
-- Secrets are stored via core.store_secret_impl (provider-specific) with references in tenant_secrets table
CREATE OR REPLACE FUNCTION core.create_tenant_secret(
  p_scope TEXT,
  p_id UUID,
  p_name TEXT,
  p_secret TEXT
) RETURNS UUID AS $$
DECLARE
  v_vault_key_id UUID;
  v_secret_id UUID;
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Validate scope
  IF p_scope NOT IN ('organization', 'user') THEN
    RAISE EXCEPTION 'Invalid scope. Must be "organization" or "user".';
  END IF;

  -- Authorization check based on scope
  IF p_scope = 'organization' THEN
    -- Only super_admin can manage organization secrets
    IF NOT EXISTS (
      SELECT 1
      FROM core.memberships m
      WHERE m.user_id = v_caller_id
        AND m.organization_id = p_id
        AND m.is_super_admin = true
        AND m.is_deleted = false
    ) THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this organization.';
    END IF;
  ELSIF p_scope = 'user' THEN
    -- Users can only manage their own secrets
    IF v_caller_id <> p_id THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this user.';
    END IF;
  END IF;

  -- Create secret via provider implementation
  v_vault_key_id := core.store_secret_impl(p_secret, p_name)::UUID;

  -- Store reference in tenant_secrets table
  INSERT INTO platform.tenant_secrets (
    scope,
    organization_id,
    user_id,
    secret_name,
    vault_key_id,
    created_by
  ) VALUES (
    p_scope,
    CASE WHEN p_scope = 'organization' THEN p_id ELSE NULL END,
    CASE WHEN p_scope = 'user' THEN p_id ELSE NULL END,
    p_name,
    v_vault_key_id,
    v_caller_id
  ) RETURNING id INTO v_secret_id;

  -- Log the action
  PERFORM core.log_audit(
    'create',
    'platform.tenant_secrets',
    v_secret_id,
    'create_tenant_secret',
    jsonb_build_object(
      'scope', p_scope,
      'secret_name', p_name,
      'target_id', p_id
    )
  );

  RETURN v_secret_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform;

-- ========================================
-- FUNCTION: core.delete_tenant_secret()
-- ========================================
-- Deletes a tenant secret for an organization or user
-- Soft-deletes the reference, hard-deletes from the secrets provider
CREATE OR REPLACE FUNCTION core.delete_tenant_secret(
  p_secret_id UUID
) RETURNS VOID AS $$
DECLARE
  v_scope TEXT;
  v_org_id UUID;
  v_user_id UUID;
  v_vault_key_id UUID;
  v_secret_name TEXT;
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- Fetch the secret details first
  SELECT scope, organization_id, user_id, vault_key_id, secret_name
  INTO v_scope, v_org_id, v_user_id, v_vault_key_id, v_secret_name
  FROM platform.tenant_secrets
  WHERE id = p_secret_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Secret not found or already deleted';
  END IF;

  -- Authorization check based on scope
  IF v_scope = 'organization' THEN
    -- Only super_admin can delete organization secrets
    IF NOT EXISTS (
      SELECT 1
      FROM core.memberships m
      WHERE m.user_id = v_caller_id
        AND m.organization_id = v_org_id
        AND m.is_super_admin = true
        AND m.is_deleted = false
    ) THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this organization.';
    END IF;
  ELSIF v_scope = 'user' THEN
    -- Users can only delete their own secrets
    IF v_caller_id <> v_user_id THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this user.';
    END IF;
  END IF;

  -- Soft-delete from tenant_secrets table
  UPDATE platform.tenant_secrets
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = v_caller_id
  WHERE id = p_secret_id
    AND is_deleted = false;

  -- Hard-delete from secrets provider (cannot be recovered)
  PERFORM core.delete_secret_impl(v_vault_key_id::TEXT);

  -- Log the action
  PERFORM core.log_audit(
    'delete',
    'platform.tenant_secrets',
    p_secret_id,
    'delete_tenant_secret',
    jsonb_build_object(
      'scope', v_scope,
      'secret_name', v_secret_name,
      'vault_key_id', v_vault_key_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform;

-- ========================================
-- FUNCTION: core.list_tenant_secrets()
-- ========================================
-- List all secrets accessible to the current user
CREATE OR REPLACE FUNCTION core.list_tenant_secrets(
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
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := core.get_current_user_id();

  -- If scope and id provided, validate authorization
  IF p_scope IS NOT NULL AND p_id IS NOT NULL THEN
    IF p_scope = 'organization' THEN
      -- Must be a member of the organization
      IF NOT EXISTS (
        SELECT 1
        FROM core.memberships m
        WHERE m.user_id = v_caller_id
          AND m.organization_id = p_id
          AND m.is_deleted = false
      ) THEN
        RAISE EXCEPTION 'You are not authorized to view secrets for this organization.';
      END IF;

      -- Return only organization secrets for this org
      RETURN QUERY
      SELECT ts.id, ts.scope, ts.organization_id, ts.user_id, ts.secret_name, ts.created_at, ts.created_by
      FROM platform.tenant_secrets ts
      WHERE ts.scope = 'organization'
        AND ts.organization_id = p_id
        AND ts.is_deleted = false
      ORDER BY ts.created_at DESC;

    ELSIF p_scope = 'user' THEN
      -- Users can only view their own secrets
      IF v_caller_id <> p_id THEN
        RAISE EXCEPTION 'You are not authorized to view secrets for this user.';
      END IF;

      -- Return only user secrets for this user
      RETURN QUERY
      SELECT ts.id, ts.scope, ts.organization_id, ts.user_id, ts.secret_name, ts.created_at, ts.created_by
      FROM platform.tenant_secrets ts
      WHERE ts.scope = 'user'
        AND ts.user_id = p_id
        AND ts.is_deleted = false
      ORDER BY ts.created_at DESC;

    ELSE
      RAISE EXCEPTION 'Invalid scope. Must be "organization" or "user".';
    END IF;
  ELSE
    -- Return all secrets the user has access to
    RETURN QUERY
    SELECT ts.id, ts.scope, ts.organization_id, ts.user_id, ts.secret_name, ts.created_at, ts.created_by
    FROM platform.tenant_secrets ts
    WHERE (
      -- User's own secrets
      (ts.scope = 'user' AND ts.user_id = v_caller_id)
      OR
      -- Organization secrets where user is a member
      (ts.scope = 'organization' AND EXISTS (
        SELECT 1
        FROM core.memberships m
        WHERE m.user_id = v_caller_id
          AND m.organization_id = ts.organization_id
          AND m.is_deleted = false
      ))
    )
    AND ts.is_deleted = false
    ORDER BY ts.created_at DESC;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core, platform;

-- ========================================
-- NOTES
-- ========================================
-- These functions use SECURITY DEFINER because:
-- 1. They need to access platform.tenant_secrets (authenticated users have no access)
-- 2. They need to call provider-specific secret storage (core.store_secret_impl / core.delete_secret_impl)
-- 3. Authorization is enforced within the function body using core.get_current_user_id()
--
-- The secret value is NEVER returned to the user - only metadata
-- Actual secret values are retrieved by the system when needed (e.g., for SMTP)
