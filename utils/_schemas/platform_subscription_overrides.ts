import { z } from 'zod';

export const platform_subscription_overridesSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid().nullable(),
  plan_override: z.string().nullable(),
  features: z.any().nullable(),
  reason: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
