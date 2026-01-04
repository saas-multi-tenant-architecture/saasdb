import { platform_settingsSchema } from '../_schemas/platform_settings';
import { PlatformSetting } from '../_types';

export function validatePlatformSetting(data: unknown): { success: true; data: PlatformSetting } | { success: false; error: any } {
  const result = platform_settingsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
