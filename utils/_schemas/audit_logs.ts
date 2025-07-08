import { z } from 'zod';

export const audit_logsSchema = z.object({
  id: z.string().uuid(),
  actor_id: z.string().uuid().nullable(),
  organization_id: z.string().uuid().nullable(),
  target_table: z.string(),
  target_id: z.string().uuid().nullable(),
  action: z.string(),
  summary: z.string().nullable(),
  metadata: z.any().nullable(),
  created_at: z.string(),
});
