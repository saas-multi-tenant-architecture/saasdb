-- products.sql
-- Purpose: Platform functions for subscription product management

-- ========================================
-- FUNCTION: platform.list_all_subscription_products()
-- ========================================
CREATE OR REPLACE FUNCTION platform.list_all_subscription_products()
RETURNS TABLE (
  id UUID,
  paymentprocessor_price_id TEXT,
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
    paymentprocessor_price_id,
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

-- ========================================
-- FUNCTION: platform.add_subscription_product()
-- ========================================
CREATE OR REPLACE FUNCTION platform.add_subscription_product(
  p_paymentprocessor_price_id TEXT,
  p_name TEXT,
  p_description TEXT,
  p_billing_interval TEXT,
  p_amount INTEGER,
  p_is_active BOOLEAN,
  p_metadata JSONB
)
RETURNS TABLE (
  id UUID,
  paymentprocessor_price_id TEXT,
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
    paymentprocessor_price_id,
    name,
    description,
    billing_interval,
    amount,
    is_active,
    metadata,
    created_by,
    updated_by
  ) VALUES (
    p_paymentprocessor_price_id,
    p_name,
    p_description,
    p_billing_interval,
    p_amount,
    p_is_active,
    p_metadata,
    core.get_current_user_id(),
    core.get_current_user_id()
  ) RETURNING * INTO v_row;

  PERFORM platform.log_platform_action('create', 'platform.subscription_products', v_row.id,
    'create_subscription_product', jsonb_build_object('name', p_name));

  RETURN QUERY SELECT
    v_row.id,
    v_row.paymentprocessor_price_id,
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
