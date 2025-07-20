import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const unitsSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  name: z.string(),
  description: z.string(),
  ...shared_auditSchema,
});
