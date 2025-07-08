import { z } from 'zod';

export const platform_organizationsSchema = z.object({
  id: z.string().uuid(),
  label: z.string(),
  notes: z.string().nullable(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
