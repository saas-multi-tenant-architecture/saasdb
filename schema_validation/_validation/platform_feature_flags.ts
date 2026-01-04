import { platform_feature_flagsSchema } from '../_schemas/platform_feature_flags';
import { PlatformFeatureFlag } from '../_types';

export function validatePlatformFeatureFlag(data: unknown): { success: true; data: PlatformFeatureFlag } | { success: false; error: any } {
  const result = platform_feature_flagsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
