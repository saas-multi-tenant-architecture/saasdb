import { organization_filesSchema } from '../_schemas/organization_files';
import { OrganizationFile } from '../_types';

export function validateOrganizationFile(data: unknown): { success: true; data: OrganizationFile } | { success: false; error: any } {
  const result = organization_filesSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
