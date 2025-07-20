import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const rolesSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  priority: z.number().int(),
  description: z.string().optional(),
  ...shared_auditSchema,
});