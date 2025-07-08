import { platform_rolesSchema } from '../_schemas/platform_roles';
import { PlatformRole } from '../_types';

export function validatePlatformRole(data: unknown): { success: true; data: PlatformRole } | { success: false; error: any } {
  const result = platform_rolesSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
