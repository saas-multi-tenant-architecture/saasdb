import { platform_organizationsSchema } from '../_schemas/platform_organizations';
import { PlatformOrganization } from '../_types';

export function validatePlatformOrganization(data: unknown): { success: true; data: PlatformOrganization } | { success: false; error: any } {
  const result = platform_organizationsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
