import { z } from 'zod/v4';

export const membershipsSchema = z.object({
  id: z.uuid(),
  user_id: z.uuid(),
  organization_id: z.uuid(),
  role_id: z.uuid(),
  created_by: z.uuid().optional(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
