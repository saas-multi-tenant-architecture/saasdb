import { tenant_secretsSchema } from '../_schemas/tenant_secrets';
import { TenantSecret } from '../_types';

export function validateTenantSecret(data: unknown): { success: true; data: TenantSecret } | { success: false; error: any } {
  const result = tenant_secretsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
