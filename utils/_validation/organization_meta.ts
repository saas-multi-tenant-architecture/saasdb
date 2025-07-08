import { organization_metaSchema } from '../_schemas/organization_meta';
import { OrganizationMeta } from '../_types';

export function validateOrganizationMeta(data: unknown): { success: true; data: OrganizationMeta } | { success: false; error: any } {
  const result = organization_metaSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
