import { platform_usersSchema } from '../_schemas/platform_users';
import { PlatformUser } from '../_types';

export function validatePlatformUser(data: unknown): { success: true; data: PlatformUser } | { success: false; error: any } {
  const result = platform_usersSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
