import { z } from 'zod/v4';

export const rolesSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  priority: z.number().int(),
  description: z.string().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
