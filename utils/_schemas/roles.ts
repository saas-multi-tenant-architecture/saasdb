import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const rolesSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().optional(),
  casl_rules: z.any(), // JSONB column to store CASL rules
  ...shared_auditSchema,
});