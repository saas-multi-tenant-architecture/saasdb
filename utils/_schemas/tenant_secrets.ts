
import { z } from 'zod/v4';

export const tenant_secretsSchema = z.object({
  id: z.uuid(),
  scope: z.enum(['organization', 'user']),
  organization_id: z.uuid().optional(),
  user_id: z.uuid().optional(),
  secret_name: z.string(),
  vault_key_id: z.uuid(),
  is_active: z.boolean().optional(),
  created_at: z.date(),
  created_by: z.uuid().optional(),
  updated_at: z.date(),
  updated_by: z.uuid().optional(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
}).check((ctx) => {
  const { value: data, issues } = ctx;
  if (data.scope === 'organization' && !data.organization_id) {
    issues.push({
      code: 'custom',
      path: ['organization_id'],
      message: 'organization_id is required when scope is organization',
      input: data.organization_id,
    });
  }
  if (data.scope === 'user' && !data.user_id) {
    issues.push({
      code: 'custom',
      path: ['user_id'],
      message: 'user_id is required when scope is user',
      input: data.user_id,
    });
  }
});