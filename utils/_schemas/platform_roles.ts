import { z } from 'zod/v4';

export const platform_rolesSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  description: z.string().optional(),
  priority: z.number().int(),
  created_at: z.date(),
  updated_at: z.date(),
});
