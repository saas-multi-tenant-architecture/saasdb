import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const platform_feature_flagsSchema = z.object({
  id: z.uuid(),
  key: z.string(),
  organization_id: z.uuid().optional(),
  description: z.string().optional(),
  value: z.unknown(),
  ...shared_auditSchema,
});
