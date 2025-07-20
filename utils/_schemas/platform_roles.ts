import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const platform_rolesSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().optional(),
  priority: z.number().int(),
  ...shared_auditSchema,
});
