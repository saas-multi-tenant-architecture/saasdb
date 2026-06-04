-- subscription_products.sql
-- Purpose: Subscription plans/products offered by the platform

-- ========================================
-- TABLE: platform.subscription_products
-- ========================================
CREATE TABLE platform.subscription_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Payment Processor Price ID for this plan (maps to Payment Processor dashboard)
  paymentprocessor_price_id TEXT NOT NULL UNIQUE,
  -- Display information
  name TEXT NOT NULL,
  description TEXT,
  billing_interval TEXT NOT NULL, -- e.g., 'monthly', 'yearly'
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
-- RLS
-- ========================================
ALTER TABLE platform.subscription_products ENABLE ROW LEVEL SECURITY;
