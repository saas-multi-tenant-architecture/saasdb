import { z } from 'zod';

export const platform_action_logsSchema = z.object({
  id: z.string().uuid(),
  platform_user_id: z.string().uuid().nullable(),
  action_type: z.string(),
  target_table: z.string().nullable(),
  target_id: z.string().uuid().nullable(),
  summary: z.string().nullable(),
  metadata: z.any().nullable(),
  created_at: z.string(),
});
