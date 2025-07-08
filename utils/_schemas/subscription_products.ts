import { z } from 'zod/v4';

export const subscription_productsSchema = z.object({
  id: z.uuid(),
  stripe_price_id: z.string(),
  name: z.string(),
  description: z.string().optional(),
  interval: z.string(),
  amount: z.number().int(),
  is_active: z.boolean().optional(),
  metadata: z.any().optional(),
  created_at: z.date(),
  updated_at: z.date(),
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
});
