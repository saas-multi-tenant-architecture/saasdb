import { z } from 'zod';

export const unitsSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
