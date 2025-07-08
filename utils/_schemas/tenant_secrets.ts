import { z } from 'zod';

export const tenant_secretsSchema = z.object({
  id: z.string().uuid(),
  scope: z.string(),
  organization_id: z.string().uuid().nullable(),
  user_id: z.string().uuid().nullable(),
  secret_name: z.string(),
  vault_key_id: z.string().uuid(),
  is_active: z.boolean().optional(),
  created_at: z.string(),
  created_by: z.string().uuid().nullable(),
  updated_at: z.string(),
  updated_by: z.string().uuid().nullable(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.string().nullable(),
  deleted_by: z.string().uuid().nullable(),
});
