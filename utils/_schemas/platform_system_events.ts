import { z } from 'zod/v4';

export const platform_system_eventsSchema = z.object({
  id: z.uuid(),
  event_type: z.string(),
  summary: z.string().optional(),
  details: z.any().optional(),
  created_by: z.uuid(),
  created_at: z.date()
});
