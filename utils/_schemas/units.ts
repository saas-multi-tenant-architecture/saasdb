import { z } from 'zod/v4';

export const unitsSchema = z.object({
  id: z.uuid(),
  organization_id: z.uuid(),
  name: z.string(),
  description: z.string(),
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
