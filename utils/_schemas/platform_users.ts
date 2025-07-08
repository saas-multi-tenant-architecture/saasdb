import { z } from 'zod';

export const platform_usersSchema = z.object({
  id: z.string().uuid(),
  supabase_user_id: z.string().uuid(),
  email: z.string(),
  role_id: z.string().uuid(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
