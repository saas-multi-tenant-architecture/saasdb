-- billing_subscriptions.sql
-- Purpose: Billing integration - tracks subscription status per organization

-- ========================================
-- TABLE: platform.billing_subscriptions
-- ========================================
CREATE TABLE platform.billing_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  paymentprocessor_subscription_id TEXT NOT NULL UNIQUE,
  plan TEXT NOT NULL,
  status TEXT NOT NULL,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_by uuid,
  updated_by uuid,
  is_deleted boolean DEFAULT false,
  deleted_at TIMESTAMPTZ,
  deleted_by uuid,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_billing_subscriptions_organization_id ON platform.billing_subscriptions (organization_id);
CREATE INDEX idx_billing_subscriptions_status ON platform.billing_subscriptions (status);

-- ========================================
-- RLS LOCKDOWN
-- ========================================
ALTER TABLE platform.billing_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_billing_subscriptions ON platform.billing_subscriptions
  FOR ALL TO public USING (false);
