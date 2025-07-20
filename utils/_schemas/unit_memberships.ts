import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

export const unit_membershipsSchema = z.object({
  id: z.uuid(),
  user_id: z.uuid(),
  unit_id: z.uuid(),
  role_id: z.uuid(),
  ...shared_auditSchema,
});
