import { z } from 'zod';

export const billing_subscriptionsSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  stripe_subscription_id: z.string(),
  plan: z.string(),
  status: z.string(),
  current_period_end: z.string().nullable(),
  cancel_at_period_end: z.boolean().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
