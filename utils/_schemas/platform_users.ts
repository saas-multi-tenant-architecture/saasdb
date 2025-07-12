import { z } from "zod/v4";

export const platform_usersSchema = z.object({
  id: z.uuid(),
  supabase_user_id: z.uuid(),
  email: z.string(),
  role_id: z.uuid(),
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  created_at: z.date(),
  updated_at: z.date(),
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
});
