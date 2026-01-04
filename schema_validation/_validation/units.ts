import { unitsSchema } from '../_schemas/units';
import { Unit } from '../_types';

export function validateUnit(data: unknown): { success: true; data: Unit } | { success: false; error: any } {
  const result = unitsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
