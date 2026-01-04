import { membershipsSchema } from '../_schemas/memberships';
import { Membership } from '../_types';

export function validateMembership(data: unknown): { success: true; data: Membership } | { success: false; error: any } {
  const result = membershipsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
