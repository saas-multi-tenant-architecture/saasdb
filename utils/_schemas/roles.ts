import { z } from 'zod';

export const rolesSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  priority: z.number().int(),
  description: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
