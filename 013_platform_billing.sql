-- 013_platform_billing.sql
-- Purpose: Define billing integration tables for Stripe and functions for mapping and tracking billing status

-- ========================================
-- TABLE: platform.billing_customers
-- ========================================
CREATE TABLE platform.billing_customers (
  organization_id UUID PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  stripe_customer_id TEXT NOT NULL UNIQUE,
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
-- TABLE: platform.billing_subscriptions
-- ========================================
CREATE TABLE platform.billing_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  stripe_subscription_id TEXT NOT NULL UNIQUE,
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
-- Note: The core.organizations table is used to link to billing to keep all tenant data
-- isolated from platform data. This is why it is not connected to the platform_organizations table.
-- The Stripe customer/subscription is conceptually tied to the tenant, not the platform’s record of that tenant


-- ========================================
-- RLS Lockdown for Billing Tables
-- ========================================
ALTER TABLE platform.billing_customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_billing_customers ON platform.billing_customers
  FOR ALL TO public USING (false);

ALTER TABLE platform.billing_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY deny_all_billing_subscriptions ON platform.billing_subscriptions
  FOR ALL TO public USING (false);

-- ========================================
-- FUNCTION: platform.link_stripe_customer
-- ========================================
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- FUNCTION: platform.record_subscription_update
-- ========================================
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- NOTES:
-- ========================================
-- All platform functions should be run by Supabase Edge Functions
-- using the service role only. These tables are not exposed to clients.
-- Need the following Edge Functions:
   -- create-checkout-session: Called when user clicks “Subscribe”
   -- handle-stripe-webhook: Called by Stripe on payment/subscription events
   -- billing-portal: Generates a link to the Stripe customer portal
-- Stripe Webhook Events are handled by a Supabase Edge Function and db function(s):
   -- Webhook will need to validate Stripe signature
   -- A list of webhook events will be created at a later date


