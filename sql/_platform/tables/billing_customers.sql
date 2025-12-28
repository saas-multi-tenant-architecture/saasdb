-- billing_customers.sql
-- Purpose: Billing integration - maps organizations to payment processor customers

-- ========================================
-- TABLE: platform.billing_customers
-- ========================================
CREATE TABLE platform.billing_customers (
  organization_id UUID PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  paymentprocessor_customer_id TEXT NOT NULL UNIQUE,
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
-- RLS LOCKDOWN
-- ========================================
ALTER TABLE platform.billing_customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_billing_customers ON platform.billing_customers
  FOR ALL TO public USING (false);

-- ========================================
-- NOTES
-- ========================================
-- The core.organizations table is used to link to billing to keep all tenant data
-- isolated from platform data. This is why it is not connected to the platform_organizations table.
-- The paymentprocessor customer/subscription is conceptually tied to the tenant, not the platform's record of that tenant
