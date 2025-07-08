import { z } from 'zod';

export const organization_metaSchema = z.object({
  id: z.string().uuid(),
  logo_url: z.string().nullable(),
  address: z.string().nullable(),
  timezone: z.string().nullable(),
  locale: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
