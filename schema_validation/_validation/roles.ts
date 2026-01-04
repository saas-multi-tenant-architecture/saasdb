import { rolesSchema } from '../_schemas/roles';
import { Role } from '../_types';

export function validateRole(data: unknown): { success: true; data: Role } | { success: false; error: any } {
  const result = rolesSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
