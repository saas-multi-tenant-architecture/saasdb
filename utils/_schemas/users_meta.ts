import { z } from 'zod/v4';

export const users_metaSchema = z.object({
  id: z.uuid(),
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  email: z.string(),
  avatar_url: z.string().optional(),
  timezone: z.string().optional(),
  locale: z.string().optional(),
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
