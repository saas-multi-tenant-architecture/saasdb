import { z } from 'zod/v4';

export const organizationsSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().optional(),
  created_by: z.uuid(),
  is_deleted: z.boolean(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
