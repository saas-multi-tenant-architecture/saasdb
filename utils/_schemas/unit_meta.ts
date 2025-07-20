import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const unit_metaSchema = z.object({
  id: z.uuid(),
  notes: z.string().nullable(),
  ...shared_auditSchema,
});
