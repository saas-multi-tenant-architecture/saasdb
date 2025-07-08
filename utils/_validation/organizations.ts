import { organizationsSchema } from '../_schemas/organizations';
import { Organization } from '../_types';

export function validateOrganization(data: unknown): { success: true; data: Organization } | { success: false; error: any } {
  const result = organizationsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
