-- billing.sql
-- Purpose: Platform functions for billing integration

-- ========================================
-- FUNCTION: platform.link_paymentprocessor_customer()
-- ========================================
CREATE OR REPLACE FUNCTION platform.link_paymentprocessor_customer(
  p_org_id UUID,
  p_paymentprocessor_customer_id TEXT,
  p_billing_email TEXT
) RETURNS VOID AS $$
BEGIN
  PERFORM platform.ensure_platform_admin();

  INSERT INTO platform.billing_customers (organization_id, paymentprocessor_customer_id, billing_email)
  VALUES (p_org_id, p_paymentprocessor_customer_id, p_billing_email)
  ON CONFLICT (organization_id) DO UPDATE
  SET paymentprocessor_customer_id = EXCLUDED.paymentprocessor_customer_id,
      billing_email = EXCLUDED.billing_email,
      updated_at = now();

  PERFORM platform.log_platform_action(
    'link', 'platform.billing_customers', p_org_id, 'Linked Payment Processor customer',
    jsonb_build_object('paymentprocessor_customer_id', p_paymentprocessor_customer_id, 'email', p_billing_email)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = platform;

-- ========================================
-- FUNCTION: platform.record_subscription_update()
-- ========================================
CREATE OR REPLACE FUNCTION platform.record_subscription_update(
  p_org_id UUID,
  p_paymentprocessor_subscription_id TEXT,
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
    organization_id, paymentprocessor_subscription_id, plan, status, current_period_end, cancel_at_period_end
  ) VALUES (
    p_org_id, p_paymentprocessor_subscription_id, p_plan, p_status, p_current_period_end, p_cancel_at_period_end
  )
  ON CONFLICT (paymentprocessor_subscription_id) DO UPDATE
  SET plan = EXCLUDED.plan,
      status = EXCLUDED.status,
      current_period_end = EXCLUDED.current_period_end,
      cancel_at_period_end = EXCLUDED.cancel_at_period_end,
      updated_at = now();

  SELECT id INTO v_sub_id FROM platform.billing_subscriptions
    WHERE paymentprocessor_subscription_id = p_paymentprocessor_subscription_id;

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

-- ========================================
-- NOTES:
-- ========================================
-- All platform functions should be run server-side (backend / serverless functions)
-- using the admin role only. These tables are not exposed to clients.
-- Need the following backend functions:
   -- create-checkout-session: Called when user clicks "Subscribe"
   -- handle-paymentprocessor-webhook: Called by Payment Processor on payment/subscription events
   -- billing-portal: Generates a link to the Payment Processor customer portal
-- Payment Processor Webhook Events are handled by a backend function and db function(s):
   -- Webhook will need to validate Payment Processor signature
   -- A list of webhook events will be created at a later date
