import { z } from 'zod/v4';

export const platform_action_logsSchema = z.object({
  id: z.uuid(),
  platform_user_id: z.uuid(),
  action_type: z.enum(['select', 'create', 'update', 'delete', 'log', 'override']),
  target_table: z.string().optional(),
  target_id: z.uuid().optional(),
  summary: z.string().optional(),
  metadata: z.any().optional(),
  created_at: z.date()
});
