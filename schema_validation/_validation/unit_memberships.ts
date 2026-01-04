import { unit_membershipsSchema } from '../_schemas/unit_memberships';
import { UnitMembership } from '../_types';

export function validateUnitMembership(data: unknown): { success: true; data: UnitMembership } | { success: false; error: any } {
  const result = unit_membershipsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
