import { z } from 'zod/v4';

export const organization_filesSchema = z.object({
  id: z.uuid(),
  file_url: z.string(),
  file_type: z.string(),
  file_specs: z.any().nullable(),
  file_size: z.number().int().nullable(),
  organization_id: z.uuid(),
  created_at: z.date(),
  updated_at: z.date(),
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
});
