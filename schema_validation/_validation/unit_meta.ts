import { unit_metaSchema } from '../_schemas/unit_meta';
import { UnitMeta } from '../_types';

export function validateUnitMeta(data: unknown): { success: true; data: UnitMeta } | { success: false; error: any } {
  const result = unit_metaSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
