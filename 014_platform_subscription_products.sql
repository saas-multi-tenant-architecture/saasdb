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
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID
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
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by UUID,
  is_deleted BOOLEAN,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID
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
    created_at,
    updated_at,
    created_by,
    is_deleted,
    deleted_at,
    deleted_by
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
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by UUID,
  is_deleted BOOLEAN,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID
) AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  RETURN QUERY
  INSERT INTO platform.subscription_products (
    stripe_price_id,
    name,
    description,
    interval,
    amount,
    is_active,
    metadata,
    created_by
  ) VALUES (
    p_stripe_price_id,
    p_name,
    p_description,
    p_interval,
    p_amount,
    p_is_active,
    p_metadata,
    auth.uid()
  ) RETURNING *;

  PERFORM platform.log_platform_action('create', 'platform.subscription_products', p_user_id,
    'create_subscription_product', jsonb_build_object('name', p_name));

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