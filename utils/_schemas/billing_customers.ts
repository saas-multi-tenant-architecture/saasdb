import { z } from 'zod';

export const billing_customersSchema = z.object({
  organization_id: z.string().uuid(),
  stripe_customer_id: z.string(),
  billing_email: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
