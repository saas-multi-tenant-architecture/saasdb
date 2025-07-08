import { z } from 'zod';

export const organization_filesSchema = z.object({
  id: z.string().uuid(),
  file_url: z.string(),
  file_type: z.string(),
  file_specs: z.any().nullable(),
  file_size: z.number().int().nullable(),
  organization_id: z.string().uuid(),
  created_at: z.string(),
  updated_at: z.string(),
  created_by: z.string().uuid().nullable(),
  updated_by: z.string().uuid().nullable(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().uuid().nullable(),
});
