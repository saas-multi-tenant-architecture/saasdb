-- 012_platform_functions.sql
-- Purpose: RPC functions for platform-level administration
-- Provides secure operations on platform tables with audit logging

-- ========================================
-- HELPER FUNCTION: platform.log_platform_action
-- ========================================
CREATE OR REPLACE FUNCTION platform.log_platform_action(
  p_action TEXT,
  p_target_table TEXT,
  p_target_id UUID,
  p_summary TEXT,
  p_metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO platform.platform_action_logs (
    platform_user_id,
    action_type,
    target_table,
    target_id,
    summary,
    metadata
  ) VALUES (
    auth.uid(),
    p_action,
    p_target_table,
    p_target_id,
    p_summary,
    p_metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- PLATFORM FUNCTIONS
-- ========================================

-- Add a new platform user with a specific role
CREATE OR REPLACE FUNCTION platform.create_platform_user(
  p_user_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_role_id UUID;
  v_email TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_role_id FROM platform.platform_roles WHERE name = p_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;

  INSERT INTO platform.platform_users (id, supabase_user_id, email, role_id)
  VALUES (p_user_id, p_user_id, v_email, v_role_id);

  PERFORM platform.log_platform_action('create', 'platform.platform_users', p_user_id,
    'create_platform_user', jsonb_build_object('role', p_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Change the assigned role for a platform user
CREATE OR REPLACE FUNCTION platform.update_platform_user_role(
  p_user_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_role_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_role_id FROM platform.platform_roles WHERE name = p_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role % not found', p_role;
  END IF;

  UPDATE platform.platform_users
  SET role_id = v_role_id,
      updated_at = now()
  WHERE id = p_user_id;

  PERFORM platform.log_platform_action('update', 'platform.platform_users', p_user_id,
    'update_platform_user_role', jsonb_build_object('role', p_role));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Soft-delete a platform user
CREATE OR REPLACE FUNCTION platform.delete_platform_user(
  p_user_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  DELETE FROM platform.platform_users
  WHERE id = p_user_id;

  PERFORM platform.log_platform_action('delete', 'platform.platform_users', p_user_id,
    'delete_platform_user', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Register a new organization in the platform control layer
CREATE OR REPLACE FUNCTION platform.create_platform_organization(
  p_organization_id UUID
) RETURNS VOID AS $$
DECLARE
  v_label TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT name INTO v_label FROM core.organizations WHERE id = p_organization_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization % not found', p_organization_id;
  END IF;

  INSERT INTO platform.platform_organizations (id, label)
  VALUES (p_organization_id, v_label);

  PERFORM platform.log_platform_action('create', 'platform.platform_organizations', p_organization_id,
    'create_platform_organization', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Store or update a subscription override for an organization
CREATE OR REPLACE FUNCTION platform.set_platform_override(
  p_organization_id UUID,
  p_key TEXT,
  p_value JSONB
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_id FROM platform.platform_subscription_overrides
  WHERE organization_id = p_organization_id;

  IF v_id IS NULL THEN
    INSERT INTO platform.platform_subscription_overrides (organization_id, features)
    VALUES (p_organization_id, jsonb_build_object(p_key, p_value))
    RETURNING id INTO v_id;
  ELSE
    UPDATE platform.platform_subscription_overrides
    SET features = jsonb_set(COALESCE(features, '{}'), ARRAY[p_key], p_value, true),
        updated_at = now()
    WHERE id = v_id;
  END IF;

  PERFORM platform.log_platform_action('override', 'platform.platform_subscription_overrides', v_id,
    'set_platform_override', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remove a subscription override
CREATE OR REPLACE FUNCTION platform.delete_platform_override(
  p_organization_id UUID,
  p_key TEXT
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT id INTO v_id FROM platform.platform_subscription_overrides
  WHERE organization_id = p_organization_id;

  IF v_id IS NOT NULL THEN
    UPDATE platform.platform_subscription_overrides
    SET features = COALESCE(features, '{}') - p_key,
        updated_at = now()
    WHERE id = v_id;
  END IF;

  PERFORM platform.log_platform_action('override', 'platform.platform_subscription_overrides', v_id,
    'delete_platform_override', jsonb_build_object('key', p_key));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Register a global or per-organization feature flag
CREATE OR REPLACE FUNCTION platform.create_platform_feature_flag(
  p_key TEXT,
  p_value JSONB,
  p_organization_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.platform_feature_flags (key, value, organization_id)
  VALUES (p_key, p_value, p_organization_id)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('create', 'platform.platform_feature_flags', v_id,
    'create_platform_feature_flag', jsonb_build_object('organization_id', p_organization_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record a system-level or admin-triggered event
CREATE OR REPLACE FUNCTION platform.log_platform_event(
  p_event_type TEXT,
  p_message TEXT,
  p_metadata JSONB
) RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.platform_system_events (event_type, summary, details)
  VALUES (p_event_type, p_message, p_metadata)
  RETURNING id INTO v_id;

  PERFORM platform.log_platform_action('log', 'platform.platform_system_events', v_id,
    'log_platform_event', jsonb_build_object('event_type', p_event_type));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Returns the current user\'s platform role
CREATE OR REPLACE FUNCTION platform.get_platform_user_role()
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
BEGIN
  PERFORM platform.ensure_platform_admin();

  SELECT pr.name INTO v_role
  FROM platform.platform_users pu
  JOIN platform.platform_roles pr ON pu.role_id = pr.id
  WHERE pu.id = auth.uid();

  RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Creates a new tenant secret for an organization or user
CREATE OR REPLACE FUNCTION platform.create_tenant_secret(
  p_scope TEXT,
  p_id UUID,
  p_name TEXT,
  p_secret TEXT,
  p_user_id UUID
) RETURNS UUID AS $$
DECLARE
  v_key_id UUID;
  v_secret_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  IF p_scope = 'organization' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM core.memberships m
      JOIN core.roles r ON r.id = m.role_id
      WHERE m.user_id = p_user_id
        AND m.organization_id = p_id
        AND r.name = 'admin'
        AND m.is_deleted = false
    ) THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this organization.';
    END IF;
  ELSIF p_scope = 'user' THEN
    IF p_user_id <> p_id THEN
      RAISE EXCEPTION 'You are not authorized to manage secrets for this user.';
    END IF;
  ELSE
    RAISE EXCEPTION 'Invalid scope';
  END IF;

  SELECT vault.create_secret(p_name, p_secret) INTO v_key_id;

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
    v_key_id,
    p_user_id
  ) RETURNING id INTO v_secret_id;

  PERFORM platform.log_platform_action('create', 'platform.tenant_secrets', v_secret_id,
    'create_tenant_secret', jsonb_build_object('scope', p_scope));

  RETURN v_secret_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Deletes a tenant secret for an organization or user
CREATE OR REPLACE FUNCTION platform.delete_tenant_secret(
  p_secret_id UUID,
  p_user_id UUID
) RETURNS VOID AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  UPDATE platform.tenant_secrets
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = p_user_id
  WHERE id = p_secret_id
    AND is_deleted = false;

  PERFORM platform.log_platform_action('delete', 'platform.tenant_secrets', p_secret_id,
    'delete_tenant_secret', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fetch recent platform actions for monitoring or audit
CREATE OR REPLACE FUNCTION platform.get_platform_action_log(
  p_limit INT DEFAULT 100
) RETURNS TABLE (
  id UUID,
  platform_user_id UUID,
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  PERFORM platform.log_platform_action('select', 'platform.platform_action_logs', NULL,
    'get_platform_action_log', jsonb_build_object('limit', p_limit));

  RETURN QUERY
  SELECT id, platform_user_id, action_type, target_table, target_id,
         summary, metadata, created_at
  FROM platform.platform_action_logs
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

