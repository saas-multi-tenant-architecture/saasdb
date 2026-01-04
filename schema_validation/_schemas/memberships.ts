import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const membershipsSchema = z.object({
  id: z.uuid(),
  user_id: z.uuid(),
  organization_id: z.uuid(),
  role_id: z.uuid(),
  is_super_admin: z.boolean().default(false),
  ...shared_auditSchema,
});
