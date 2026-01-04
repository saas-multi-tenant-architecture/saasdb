import { audit_logsSchema } from '../_schemas/audit_logs';
import { AuditLog } from '../_types';

export function validateAuditLog(data: unknown): { success: true; data: AuditLog } | { success: false; error: any } {
  const result = audit_logsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
