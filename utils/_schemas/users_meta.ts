import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const users_metaSchema = z.object({
  id: z.uuid(),
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  email: z.string(),
  avatar_url: z.string().optional(),
  timezone: z.string().optional(),
  locale: z.string().optional(),
  ...shared_auditSchema,
});
