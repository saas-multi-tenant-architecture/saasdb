-- products.sql
-- Purpose: Public function to list available subscription products

-- ========================================
-- FUNCTION: public.list_subscription_products()
-- ========================================
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
