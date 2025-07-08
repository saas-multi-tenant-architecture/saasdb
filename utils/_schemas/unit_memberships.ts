import { z } from 'zod';

export const unit_membershipsSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  unit_id: z.string().uuid(),
  role_id: z.string().uuid(),
  created_by: z.string().uuid().nullable(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
