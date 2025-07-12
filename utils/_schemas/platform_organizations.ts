import { z } from "zod/v4";

export const platform_organizationsSchema = z.object({
  id: z.uuid(),
  label: z.string(),
  notes: z.string().optional(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
});
