import { z } from 'zod';

export const platform_settingsSchema = z.object({
  key: z.string(),
  value: z.any(),
  description: z.string().nullable(),
  updated_at: z.string(),
});
