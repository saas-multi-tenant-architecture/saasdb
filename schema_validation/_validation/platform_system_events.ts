import { platform_system_eventsSchema } from '../_schemas/platform_system_events';
import { PlatformSystemEvent } from '../_types';

export function validatePlatformSystemEvent(data: unknown): { success: true; data: PlatformSystemEvent } | { success: false; error: any } {
  const result = platform_system_eventsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
