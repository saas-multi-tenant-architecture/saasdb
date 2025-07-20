import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const organization_filesSchema = z.object({
  id: z.uuid(),
  file_url: z.string(),
  file_type: z.string(),
  file_specs: z.any().nullable(),
  file_size: z.number().int().nullable(),
  organization_id: z.uuid(),
  ...shared_auditSchema,
});
