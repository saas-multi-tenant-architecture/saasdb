import { z } from 'zod';

export const platform_feature_flagsSchema = z.object({
  id: z.string().uuid(),
  key: z.string(),
  organization_id: z.string().uuid().nullable(),
  description: z.string().nullable(),
  value: z.any(),
  is_active: z.boolean().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
