import { platform_subscription_overridesSchema } from '../_schemas/platform_subscription_overrides';
import { PlatformSubscriptionOverride } from '../_types';

export function validatePlatformSubscriptionOverride(data: unknown): { success: true; data: PlatformSubscriptionOverride } | { success: false; error: any } {
  const result = platform_subscription_overridesSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
