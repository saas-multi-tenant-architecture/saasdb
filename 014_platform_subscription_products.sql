-- 014_platform_subscription_products.sql
-- Purpose: Define table for subscription plans/products offered by the platform

-- ========================================
-- TABLE: platform.subscription_products
-- ========================================
CREATE TABLE platform.subscription_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Stripe Price ID for this plan (maps to Stripe dashboard)
  stripe_price_id TEXT NOT NULL UNIQUE,
  -- Display information
  name TEXT NOT NULL,
  description TEXT,
  interval TEXT NOT NULL, -- e.g., 'monthly', 'yearly'
  amount INTEGER NOT NULL, -- amount in cents
  is_active BOOLEAN DEFAULT true,
  -- Optional metadata for internal use or future extension
  metadata JSONB,
  -- Standard audit fields
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- RLS Lockdown
-- ========================================
ALTER TABLE platform.subscription_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY deny_all_subscription_products ON platform.subscription_products
  FOR ALL TO public USING (false);

-- ========================================
-- FUNCTION: platform.list_all_subscription_products()
-- ========================================
CREATE OR REPLACE FUNCTION platform.list_all_subscription_products()
RETURNS TABLE (
  id UUID,
  stripe_price_id TEXT,
  name TEXT,
  description TEXT,
  interval TEXT,
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
    interval,
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- FUNCTION: platform.add_subscription_product()
-- ========================================
CREATE OR REPLACE FUNCTION platform.add_subscription_product(
  p_stripe_price_id TEXT,
  p_name TEXT,
  p_description TEXT,
  p_interval TEXT,
  p_amount INTEGER,
  p_is_active BOOLEAN,
  p_metadata JSONB
)
RETURNS TABLE (
  id UUID,
  stripe_price_id TEXT,
  name TEXT,
  description TEXT,
  interval TEXT,
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
    interval,
    amount,
    is_active,
    metadata,
    created_by,
    updated_by
  ) VALUES (
    p_stripe_price_id,
    p_name,
    p_description,
    p_interval,
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
    v_row.interval,
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
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ========================================
-- FUNCTION: public.list_subscription_products()
-- ========================================
CREATE OR REPLACE FUNCTION public.list_subscription_products()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  interval TEXT,
  amount INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    id,
    name,
    description,
    interval,
    amount
  FROM platform.subscription_products
  WHERE is_active = true AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;