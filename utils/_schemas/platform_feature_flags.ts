import { z } from 'zod/v4';

export const platform_feature_flagsSchema = z.object({
  id: z.uuid(),
  key: z.string(),
  organization_id: z.uuid().optional(),
  description: z.string().optional(),
  value: z.any(),
  is_active: z.boolean(),
  created_at: z.date(),
  updated_at: z.date(),
});
