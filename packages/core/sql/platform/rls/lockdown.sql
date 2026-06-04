-- lockdown.sql
-- Purpose: Lock down all platform tables using RLS with USING (false), and create a secure access guard function

-- ========================================
-- FUNCTION: platform.is_platform_user()
-- ========================================
CREATE OR REPLACE FUNCTION platform.is_platform_user()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM platform.platform_users pu
    WHERE pu.supabase_user_id = auth.uid()
      AND pu.is_deleted = false
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = platform, public;

-- ========================================
-- FUNCTION: platform.is_platform_super_admin()
-- ========================================
CREATE OR REPLACE FUNCTION platform.is_platform_super_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM platform.platform_users pu
    JOIN platform.platform_roles pr ON pu.role_id = pr.id
    WHERE pu.supabase_user_id = auth.uid()
      AND pu.is_deleted = false
      AND pr.name = 'super_admin'
  );
$$ LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = platform, public;

-- ========================================
-- FUNCTION: platform.ensure_platform_user()
-- ========================================
CREATE OR REPLACE FUNCTION platform.ensure_platform_user()
RETURNS VOID AS $$
BEGIN
  IF NOT platform.is_platform_user() THEN
    RAISE EXCEPTION 'Access denied: platform user required';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.ensure_platform_admin()
-- ========================================
-- NOTE: Despite the name, this enforces platform super_admin only.
CREATE OR REPLACE FUNCTION platform.ensure_platform_admin()
RETURNS VOID AS $$
BEGIN
  IF NOT platform.is_platform_super_admin() THEN
    RAISE EXCEPTION 'Access denied: platform super_admin role required';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- RLS LOCKDOWN: Enable RLS and deny all for platform tables
-- ========================================
ALTER TABLE platform.platform_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_users_select ON platform.platform_users
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_users_insert ON platform.platform_users
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_users_update ON platform.platform_users
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_roles_select ON platform.platform_roles
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_roles_insert ON platform.platform_roles
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_roles_update ON platform.platform_roles
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_action_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_action_logs_select ON platform.platform_action_logs
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_action_logs_insert ON platform.platform_action_logs
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_organizations_select ON platform.platform_organizations
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_organizations_insert ON platform.platform_organizations
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_organizations_update ON platform.platform_organizations
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_subscription_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_subscription_overrides_select ON platform.platform_subscription_overrides
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_subscription_overrides_insert ON platform.platform_subscription_overrides
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_subscription_overrides_update ON platform.platform_subscription_overrides
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_feature_flags_select ON platform.platform_feature_flags
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_feature_flags_insert ON platform.platform_feature_flags
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_feature_flags_update ON platform.platform_feature_flags
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_settings_select ON platform.platform_settings
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_settings_insert ON platform.platform_settings
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY platform_settings_update ON platform.platform_settings
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.platform_system_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY platform_system_events_select ON platform.platform_system_events
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY platform_system_events_insert ON platform.platform_system_events
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

ALTER TABLE platform.tenant_secrets ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_secrets_select ON platform.tenant_secrets
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY tenant_secrets_insert ON platform.tenant_secrets
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY tenant_secrets_update ON platform.tenant_secrets
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

-- ========================================
-- PLATFORM RLS: Billing + products tables
-- ========================================
-- These tables may already have deny_all_* policies in their table definitions.

CREATE POLICY billing_customers_select ON platform.billing_customers
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY billing_customers_insert ON platform.billing_customers
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY billing_customers_update ON platform.billing_customers
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY billing_subscriptions_select ON platform.billing_subscriptions
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY billing_subscriptions_insert ON platform.billing_subscriptions
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY billing_subscriptions_update ON platform.billing_subscriptions
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY subscription_products_select ON platform.subscription_products
  FOR SELECT TO authenticated
  USING (platform.is_platform_user());

CREATE POLICY subscription_products_insert ON platform.subscription_products
  FOR INSERT TO authenticated
  WITH CHECK (platform.is_platform_super_admin());

CREATE POLICY subscription_products_update ON platform.subscription_products
  FOR UPDATE TO authenticated
  USING (platform.is_platform_super_admin())
  WITH CHECK (platform.is_platform_super_admin());
