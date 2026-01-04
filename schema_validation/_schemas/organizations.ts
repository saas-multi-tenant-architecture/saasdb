import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const organizationsSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().optional(),
  ...shared_auditSchema,  
});
