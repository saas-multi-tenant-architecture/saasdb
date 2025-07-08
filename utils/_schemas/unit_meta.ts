import { z } from 'zod/v4';

export const unit_metaSchema = z.object({
  id: z.uuid(),
  notes: z.string().nullable(),
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
