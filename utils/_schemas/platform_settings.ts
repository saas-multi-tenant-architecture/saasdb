import { z } from 'zod/v4';

export const platform_settingsSchema = z.object({
  key: z.string(),
  value: z.any(),
  description: z.string().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
