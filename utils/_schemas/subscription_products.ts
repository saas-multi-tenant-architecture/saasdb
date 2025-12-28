import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const subscription_productsSchema = z.object({
  id: z.uuid(),
  paymentprocessor_price_id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  billing_interval: z.string(),
  amount: z.number().int(),
  is_active: z.boolean().default(true),
  metadata: z.any().nullable(),
  ...shared_auditSchema,
});
