import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const billing_customersSchema = z.object({
  organization_id: z.uuid(),
  paymentprocessor_customer_id: z.string(),
  billing_email: z.string().optional(),
  ...shared_auditSchema,
});
