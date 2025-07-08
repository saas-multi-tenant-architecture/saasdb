import { z } from 'zod';

export const users_metaSchema = z.object({
  id: z.string().uuid(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  email: z.string().nullable(),
  avatar_url: z.string().nullable(),
  timezone: z.string().nullable(),
  locale: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
