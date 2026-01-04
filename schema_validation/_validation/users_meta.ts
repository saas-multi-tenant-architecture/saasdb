import { users_metaSchema } from '../_schemas/users_meta';
import { UsersMeta } from '../_types';

export function validateUsersMeta(data: unknown): { success: true; data: UsersMeta } | { success: false; error: any } {
  const result = users_metaSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
