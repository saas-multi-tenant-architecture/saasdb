import { z } from 'zod';

export const unit_metaSchema = z.object({
  id: z.string().uuid(),
  notes: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
