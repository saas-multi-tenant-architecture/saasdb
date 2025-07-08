import { z } from 'zod';

export const subscription_productsSchema = z.object({
  id: z.string().uuid(),
  stripe_price_id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  interval: z.string(),
  amount: z.number().int(),
  is_active: z.boolean().optional(),
  metadata: z.any().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  created_by: z.string().uuid().nullable(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().uuid().nullable(),
});
