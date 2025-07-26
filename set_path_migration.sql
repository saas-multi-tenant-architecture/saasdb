-- =====================
-- public.list_files
-- =====================
CREATE OR REPLACE FUNCTION public.list_files(p_org_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE organization_id = p_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.delete_file
-- =====================
CREATE OR REPLACE FUNCTION public.delete_file(p_file_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.organization_files
  SET
    is_deleted = true,
    deleted_at = now(),
    deleted_by = auth.uid()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'delete', 'core.organization_files', p_file_id, 'delete_file',
    jsonb_build_object(
      'file_id', p_file_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.get_audit_log
-- =====================
CREATE OR REPLACE FUNCTION public.get_audit_log(p_org_id UUID, p_limit INT)
RETURNS TABLE (
  id UUID,
  actor_id UUID,
  target_table TEXT,
  target_id UUID,
  action TEXT,
  summary TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, actor_id, target_table, target_id, action, summary, metadata, created_at
  FROM core.audit_logs
  WHERE organization_id = p_org_id
  ORDER BY created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- platform.add_subscription_product
-- =====================
CREATE OR REPLACE FUNCTION platform.add_subscription_product(
  p_stripe_price_id TEXT,
  p_name TEXT,
  p_description TEXT,
  p_billing_interval TEXT,
  p_amount INTEGER,
  p_is_active BOOLEAN,
  p_metadata JSONB
)
RETURNS TABLE (
  id UUID,
  stripe_price_id TEXT,
  name TEXT,
  description TEXT,
  billing_interval TEXT,
  amount INTEGER,
  is_active BOOLEAN,
  metadata JSONB,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
DECLARE
  v_row platform.subscription_products%ROWTYPE;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.subscription_products (
    stripe_price_id,
    name,
    description,
    billing_interval,
    amount,
    is_active,
    metadata,
    created_by,
    updated_by
  ) VALUES (
    p_stripe_price_id,
    p_name,
    p_description,
    p_billing_interval,
    p_amount,
    p_is_active,
    p_metadata,
    auth.uid(),
    auth.uid()
  ) RETURNING * INTO v_row;

  PERFORM platform.log_platform_action('create', 'platform.subscription_products', v_row.id,
    'create_subscription_product', jsonb_build_object('name', p_name));

  RETURN QUERY SELECT
    v_row.id,
    v_row.stripe_price_id,
    v_row.name,
    v_row.description,
    v_row.billing_interval,
    v_row.amount,
    v_row.is_active,
    v_row.metadata,
    v_row.created_by,
    v_row.updated_by,
    v_row.is_deleted,
    v_row.deleted_at,
    v_row.deleted_by,
    v_row.created_at,
    v_row.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- public.list_subscription_products
-- =====================
CREATE OR REPLACE FUNCTION public.list_subscription_products()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  billing_interval TEXT,
  amount INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    id,
    name,
    description,
    billing_interval,
    amount,
    created_at,
    updated_at,
    created_by,
    updated_by
  FROM platform.subscription_products
  WHERE is_active = true AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =====================
-- platform.ensure_platform_admin
-- =====================
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


-- =====================
-- utils.update_timestamp
-- =====================
CREATE OR REPLACE FUNCTION utils.update_timestamp()


-- =====================
-- platform.log_platform_action
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.create_platform_user
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.update_platform_user_role
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.delete_platform_user
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.create_platform_organization
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.set_platform_override
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.delete_platform_override
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.create_platform_feature_flag
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.log_platform_event
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.get_platform_user_role
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.create_tenant_secret
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.delete_tenant_secret
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.get_platform_action_log
-- =====================
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- core.handle_new_user
-- =====================
CREATE OR REPLACE FUNCTION core.handle_new_user()


-- =====================
-- public.get_user_profile
-- =====================
CREATE OR REPLACE FUNCTION public.get_user_profile()
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.id,
    m.email,
    m.first_name,
    m.last_name,
    m.avatar_url,
    m.timezone,
    m.locale
  FROM core.users_meta m
  WHERE m.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- platform.link_stripe_customer
-- =====================
CREATE OR REPLACE FUNCTION platform.link_stripe_customer(
  p_org_id UUID,
  p_stripe_customer_id TEXT,
  p_billing_email TEXT
) RETURNS VOID AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.billing_customers (organization_id, stripe_customer_id, billing_email)
  VALUES (p_org_id, p_stripe_customer_id, p_billing_email)
  ON CONFLICT (organization_id) DO UPDATE
  SET stripe_customer_id = EXCLUDED.stripe_customer_id,
      billing_email = EXCLUDED.billing_email,
      updated_at = now();

  PERFORM platform.log_platform_action(
    'link', 'platform.billing_customers', p_org_id, 'Linked Stripe customer',
    jsonb_build_object('stripe_customer_id', p_stripe_customer_id, 'email', p_billing_email)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- platform.record_subscription_update
-- =====================
CREATE OR REPLACE FUNCTION platform.record_subscription_update(
  p_org_id UUID,
  p_stripe_subscription_id TEXT,
  p_plan TEXT,
  p_status TEXT,
  p_current_period_end TIMESTAMPTZ,
  p_cancel_at_period_end BOOLEAN
) RETURNS VOID AS $$
DECLARE
  v_sub_id UUID;
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.billing_subscriptions (
    organization_id, stripe_subscription_id, plan, status, current_period_end, cancel_at_period_end
  ) VALUES (
    p_org_id, p_stripe_subscription_id, p_plan, p_status, p_current_period_end, p_cancel_at_period_end
  )
  ON CONFLICT (stripe_subscription_id) DO UPDATE
  SET plan = EXCLUDED.plan,
      status = EXCLUDED.status,
      current_period_end = EXCLUDED.current_period_end,
      cancel_at_period_end = EXCLUDED.cancel_at_period_end,
      updated_at = now();

  SELECT id INTO v_sub_id FROM platform.billing_subscriptions
    WHERE stripe_subscription_id = p_stripe_subscription_id;

  PERFORM platform.log_platform_action(
    'update', 'platform.billing_subscriptions', v_sub_id, 'Updated subscription status',
    jsonb_build_object(
      'plan', p_plan,
      'status', p_status,
      'current_period_end', p_current_period_end,
      'cancel_at_period_end', p_cancel_at_period_end
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- core.handle_new_organization
-- =====================
CREATE OR REPLACE FUNCTION core.handle_new_organization()


-- =====================
-- core.is_org_member
-- =====================
CREATE OR REPLACE FUNCTION core.is_org_member(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.memberships
    WHERE user_id = auth.uid()
      AND organization_id = p_org_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE


-- =====================
-- core.is_unit_member
-- =====================
CREATE OR REPLACE FUNCTION core.is_unit_member(p_unit_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.unit_memberships
    WHERE user_id = auth.uid()
      AND unit_id = p_unit_id
      AND is_deleted = false
  );
$$ LANGUAGE sql STABLE


-- =====================
-- core.get_org_role
-- =====================
CREATE OR REPLACE FUNCTION core.get_org_role(p_org_id UUID)
RETURNS TEXT AS $$
  SELECT r.name
  FROM core.memberships m
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = auth.uid()
    AND m.organization_id = p_org_id
    AND m.is_deleted = false
  LIMIT 1;
$$ LANGUAGE sql STABLE


-- =====================
-- core.has_org_role
-- =====================
CREATE OR REPLACE FUNCTION core.has_org_role(p_org_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT core.get_org_role(p_org_id) = p_role;
$$ LANGUAGE sql STABLE


-- =====================
-- core.has_unit_role
-- =====================
CREATE OR REPLACE FUNCTION core.has_unit_role(p_unit_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM core.unit_memberships um
    JOIN core.roles r ON r.id = um.role_id
    WHERE um.user_id = auth.uid()
      AND um.unit_id = p_unit_id
      AND um.is_deleted = false
      AND r.name = p_role
  );
$$ LANGUAGE sql STABLE


-- =====================
-- core.shares_organization
-- =====================
CREATE OR REPLACE FUNCTION core.shares_organization(p_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM core.memberships m1
    JOIN core.memberships m2 ON m1.organization_id = m2.organization_id
    WHERE m1.user_id = auth.uid()
      AND m2.user_id = p_user_id
      AND m1.is_deleted = false
      AND m2.is_deleted = false
  );
$$ LANGUAGE sql STABLE


-- =====================
-- platform.list_all_subscription_products
-- =====================
CREATE OR REPLACE FUNCTION platform.list_all_subscription_products()
RETURNS TABLE (
  id UUID,
  stripe_price_id TEXT,
  name TEXT,
  description TEXT,
  billing_interval TEXT,
  amount INTEGER,
  is_active BOOLEAN,
  metadata JSONB,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN

  PERFORM platform.ensure_platform_admin();
  
  RETURN QUERY
  SELECT
    id,
    stripe_price_id,
    name,
    description,
    billing_interval,
    amount,
    is_active,
    metadata,
    created_by,
    updated_by,
    is_deleted,
    deleted_at,
    deleted_by,
    created_at,
    updated_at
  FROM platform.subscription_products
  WHERE is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;


-- =====================
-- core.log_audit
-- =====================
CREATE OR REPLACE FUNCTION core.log_audit(
  action_type TEXT,
  target_table TEXT,
  target_id UUID,
  summary TEXT,
  metadata JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO core.audit_logs (
    actor_id,
    target_table,
    target_id,
    action,
    summary,
    metadata
  ) VALUES (
    auth.uid(),
    target_table,
    target_id,
    action_type,
    summary,
    metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = core;


-- =====================
-- public.update_user_profile
-- =====================
CREATE OR REPLACE FUNCTION public.update_user_profile(p_data JSON)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  timezone TEXT,
  locale TEXT
) AS $$
DECLARE
  v_row core.users_meta%ROWTYPE;
BEGIN
  UPDATE core.users_meta
  SET first_name = COALESCE(p_data->>'first_name', first_name),
      last_name  = COALESCE(p_data->>'last_name', last_name),
      avatar_url = COALESCE(p_data->>'avatar_url', avatar_url),
      timezone   = COALESCE(p_data->>'timezone', timezone),
      locale     = COALESCE(p_data->>'locale', locale)
  WHERE id = auth.uid()
  RETURNING * INTO v_row;

  PERFORM core.log_audit('update', 'core.users_meta', auth.uid(), 'update_user_profile', p_data);

  RETURN QUERY SELECT
    v_row.id,
    (SELECT email FROM auth.users WHERE id = v_row.id),
    v_row.first_name,
    v_row.last_name,
    v_row.avatar_url,
    v_row.timezone,
    v_row.locale;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.list_my_organizations
-- =====================
CREATE OR REPLACE FUNCTION public.list_my_organizations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.name, o.description, r.name AS role
  FROM core.organizations o
  JOIN core.memberships m ON m.organization_id = o.id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.user_id = auth.uid()
    AND m.is_deleted = false
    AND o.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.get_organization
-- =====================
CREATE OR REPLACE FUNCTION public.get_organization(p_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  updated_by UUID,
  is_deleted BOOLEAN,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, name, description, created_by, created_at, updated_by, updated_at, is_deleted, deleted_at, deleted_by
  FROM core.organizations
  WHERE id = p_id
    AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.list_organization_members
-- =====================
CREATE OR REPLACE FUNCTION public.list_organization_members(p_id UUID)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT m.user_id,
         u.email,
         um.first_name,
         um.last_name,
         r.name AS role
  FROM core.memberships m
  JOIN auth.users u ON u.id = m.user_id
  JOIN core.users_meta um ON um.id = m.user_id
  JOIN core.roles r ON r.id = m.role_id
  WHERE m.organization_id = p_id
    AND m.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.get_user_role
-- =====================
CREATE OR REPLACE FUNCTION public.get_user_role(p_org_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN core.get_org_role(p_org_id);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.create_organization
-- =====================
CREATE OR REPLACE FUNCTION public.create_organization(p_name TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_org_id UUID;
  v_admin_role UUID;
BEGIN
  INSERT INTO core.organizations (name, created_by)
  VALUES (p_name, auth.uid())
  RETURNING id INTO v_org_id;

  SELECT id INTO v_admin_role FROM core.roles WHERE name = 'admin' LIMIT 1;
  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (auth.uid(), v_org_id, v_admin_role, auth.uid());

  PERFORM core.log_audit('insert', 'core.organizations', v_org_id, 'create_organization', jsonb_build_object('name', p_name));

  RETURN QUERY SELECT id, name, created_at FROM core.organizations WHERE id = v_org_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.invite_user_to_organization
-- =====================
CREATE OR REPLACE FUNCTION public.invite_user_to_organization(p_email TEXT, p_role_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_org_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  SELECT organization_id INTO v_org_id FROM core.memberships
  WHERE user_id = auth.uid() AND is_deleted = false
  LIMIT 1;

  INSERT INTO core.memberships (user_id, organization_id, role_id, created_by)
  VALUES (v_user_id, v_org_id, p_role_id, auth.uid());

  PERFORM core.log_audit('insert', 'core.memberships', v_user_id, 'invite_user_to_organization', jsonb_build_object('organization_id', v_org_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.remove_user_from_organization
-- =====================
CREATE OR REPLACE FUNCTION public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid()
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.memberships', p_user_id, 'remove_user_from_organization', jsonb_build_object('organization_id', p_org_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.list_my_units
-- =====================
CREATE OR REPLACE FUNCTION public.list_my_units()
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  role TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.organization_id, u.name, r.name AS role
  FROM core.units u
  JOIN core.unit_memberships um ON um.unit_id = u.id
  JOIN core.roles r ON r.id = um.role_id
  WHERE um.user_id = auth.uid()
    AND um.is_deleted = false
    AND u.is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.get_unit
-- =====================
CREATE OR REPLACE FUNCTION public.get_unit(p_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, name, description, created_at, updated_at
  FROM core.units
  WHERE id = p_id
    AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.create_unit
-- =====================
CREATE OR REPLACE FUNCTION public.create_unit(
  p_org_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  name TEXT,
  description TEXT,
  created_by UUID,
  updated_by UUID
) AS $$
DECLARE
  v_unit_id UUID;
BEGIN
  INSERT INTO core.units (organization_id, name, description, created_by, updated_by)
  VALUES (p_org_id, p_name, p_description, auth.uid(), auth.uid())
  RETURNING id INTO v_unit_id;

  PERFORM core.log_audit('insert', 'core.units', v_unit_id, 'create_unit', jsonb_build_object('organization_id', p_org_id, 'name', p_name));

  RETURN QUERY SELECT id, organization_id, name, created_by, updated_by FROM core.units WHERE id = v_unit_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.assign_user_to_unit
-- =====================
CREATE OR REPLACE FUNCTION public.assign_user_to_unit(p_user_id UUID, p_unit_id UUID, p_role_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO core.unit_memberships (user_id, unit_id, role_id, created_by)
  VALUES (p_user_id, p_unit_id, p_role_id, auth.uid());

  PERFORM core.log_audit('insert', 'core.unit_memberships', p_user_id, 'assign_user_to_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.remove_user_from_unit
-- =====================
CREATE OR REPLACE FUNCTION public.remove_user_from_unit(p_user_id UUID, p_unit_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE core.unit_memberships
  SET is_deleted = true,
      deleted_at = now(),
      deleted_by = auth.uid()
  WHERE user_id = p_user_id
    AND unit_id = p_unit_id
    AND is_deleted = false;

  PERFORM core.log_audit('delete', 'core.unit_memberships', p_user_id, 'remove_user_from_unit', jsonb_build_object('unit_id', p_unit_id));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.create_file
-- =====================
CREATE OR REPLACE FUNCTION public.create_file(
  p_org_id UUID,
  p_file_url TEXT,
  p_file_type TEXT,
  p_file_size INTEGER DEFAULT NULL,
  p_file_specs JSONB DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_file_id UUID;
BEGIN
  INSERT INTO core.organization_files (
    organization_id, file_url, file_type, file_size, file_specs, created_by
  )
  VALUES (
    p_org_id, p_file_url, p_file_type, p_file_size, p_file_specs, auth.uid()
  )
  RETURNING id INTO v_file_id;

  PERFORM core.log_audit(
    'insert', 'core.organization_files', v_file_id, 'create_file',
    jsonb_build_object(
      'file_url', p_file_url,
      'file_type', p_file_type,
      'file_size', p_file_size,
      'file_specs', p_file_specs
    )
  );

  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at
  FROM core.organization_files
  WHERE id = v_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.update_file_metadata
-- =====================
CREATE OR REPLACE FUNCTION public.update_file_metadata(
  p_file_id UUID,
  p_file_specs JSONB DEFAULT NULL,
  p_file_size INTEGER DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  file_url TEXT,
  file_type TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  UPDATE core.organization_files
  SET
    file_specs = COALESCE(p_file_specs, file_specs),
    file_size = COALESCE(p_file_size, file_size),
    updated_by = auth.uid(),
    updated_at = now()
  WHERE id = p_file_id;

  PERFORM core.log_audit(
    'update', 'core.organization_files', p_file_id, 'update_file_metadata',
    jsonb_build_object(
      'file_specs', p_file_specs,
      'file_size', p_file_size
    )
  );

  RETURN QUERY
  SELECT id, file_url, file_type, updated_at FROM core.organization_files WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- =====================
-- public.get_file
-- =====================
CREATE OR REPLACE FUNCTION public.get_file(p_file_id UUID)
RETURNS TABLE (
  id UUID,
  organization_id UUID,
  file_url TEXT,
  file_type TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, organization_id, file_url, file_type, created_at, updated_at
  FROM core.organization_files
  WHERE id = p_file_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


