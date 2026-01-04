import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const platform_settingsSchema = z.object({
  key: z.string(),
  value: z.any(),
  description: z.string().optional(),
  ...shared_auditSchema,
});
