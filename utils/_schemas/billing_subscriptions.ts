import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const billing_subscriptionsSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  stripe_subscription_id: z.string(),
  plan: z.string(),
  status: z.string(),
  current_period_end: z.date().optional(),
  cancel_at_period_end: z.boolean().optional(),
  ...shared_auditSchema,
});
