-- billing_customers.sql
-- Purpose: Billing integration - maps organizations to payment processor customers

-- ========================================
-- TABLE: platform.billing_customers
-- ========================================
CREATE TABLE platform.billing_customers (
  organization_id UUID PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  provider_customer_id TEXT NOT NULL UNIQUE,
  provider TEXT NOT NULL DEFAULT 'stripe' CONSTRAINT billing_customers_provider_check CHECK (provider IN ('stripe', 'lemon_squeezy')),
  billing_email TEXT,
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
ALTER TABLE platform.billing_customers ENABLE ROW LEVEL SECURITY;

-- ========================================
-- NOTES
-- ========================================
-- The core.organizations table is used to link to billing to keep all tenant data
-- isolated from platform data. This is why it is not connected to the platform_organizations table.
-- The paymentprocessor customer/subscription is conceptually tied to the tenant, not the platform's record of that tenant
