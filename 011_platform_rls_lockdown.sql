-- 011_platform_rls_lockdown.sql
-- Purpose: Lock down all platform tables using RLS with USING (false), and create a secure access guard function

-- ========================================
-- FUNCTION: platform.ensure_platform_admin()
-- ========================================
CREATE OR REPLACE FUNCTION platform.ensure_platform_admin()
RETURNS VOID AS $$
DECLARE
  is_admin BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM platform.platform_users pu
    JOIN platform.platform_roles pr ON pu.role_id = pr.id
    WHERE pu.id = auth.uid()
      AND pr.name = 'admin'
  ) INTO is_admin;

  IF NOT is_admin THEN
    RAISE EXCEPTION 'Access denied: platform admin role required';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- RLS Lockdown: Enable RLS and deny all for platform tables
-- ========================================
ALTER TABLE platform.platform_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_users ON platform.platform_users
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_roles ON platform.platform_roles
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_action_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_action_logs ON platform.platform_action_logs
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_organizations ON platform.platform_organizations
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_subscription_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_subscription_overrides ON platform.platform_subscription_overrides
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_feature_flags ON platform.platform_feature_flags
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_settings ON platform.platform_settings
  FOR ALL TO public USING (false);

ALTER TABLE platform.platform_system_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_platform_system_events ON platform.platform_system_events
  FOR ALL TO public USING (false);

ALTER TABLE platform.tenant_secrets ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_tenant_secrets ON platform.tenant_secrets
  FOR ALL TO public USING (false);