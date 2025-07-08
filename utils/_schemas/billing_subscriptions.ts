import { z } from 'zod/v4';

export const billing_subscriptionsSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  stripe_subscription_id: z.string(),
  plan: z.string(),
  status: z.string(),
  current_period_end: z.date().optional(),
  cancel_at_period_end: z.boolean().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
