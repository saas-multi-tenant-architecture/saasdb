import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const organizations_metaSchema = z.object({
  id: z.uuid(),
  logo_file_id: z.uuid().optional(), // FK relationship to organization_files
  address: z.string().optional(),
  timezone: z.string().optional(),
  locale: z.string().optional(),
  ...shared_auditSchema,
});
