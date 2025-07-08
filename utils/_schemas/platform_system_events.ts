import { z } from 'zod';

export const platform_system_eventsSchema = z.object({
  id: z.string().uuid(),
  event_type: z.string(),
  summary: z.string().nullable(),
  details: z.any().nullable(),
  created_at: z.string(),
});
