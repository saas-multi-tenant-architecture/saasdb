import { z } from 'zod/v4';

export const audit_logsSchema = z.object({
  id: z.uuid(),  
  actor_id: z.uuid().optional(),
  organization_id: z.uuid().optional(),
  target_table: z.string(),
  target_id: z.uuid().optional(),
  action: z.enum(['select', 'create', 'update', 'delete', 'log', 'override']),
  summary: z.string().optional(),
  metadata: z.any().optional(),
  created_at: z.date()
});
