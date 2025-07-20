import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const subscription_productsSchema = z.object({
  id: z.uuid(),
  stripe_price_id: z.string(),
  name: z.string(),
  description: z.string().optional(),
  interval: z.string(),
  amount: z.number().int(),
  is_active: z.boolean().optional(),
  metadata: z.any().optional(),
  ...shared_auditSchema,
});
