import { platform_action_logsSchema } from '../_schemas/platform_action_logs';
import { PlatformActionLog } from '../_types';

export function validatePlatformActionLog(data: unknown): { success: true; data: PlatformActionLog } | { success: false; error: any } {
  const result = platform_action_logsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
