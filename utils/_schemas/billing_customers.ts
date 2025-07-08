import { z } from 'zod/v4';

export const billing_customersSchema = z.object({
  organization_id: z.uuid(),
  stripe_customer_id: z.string(),
  billing_email: z.string().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
