import { z } from 'zod';

export const platform_rolesSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  priority: z.number().int(),
  created_at: z.string(),
  updated_at: z.string(),
});
