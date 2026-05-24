// SYNC-CHECK: public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)
// SYNC-CHECK: public.get_organization(p_id UUID)
// SYNC-CHECK: public.list_my_organizations()
// SYNC-CHECK: public.update_organization(p_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.list_organization_members(p_id UUID)
// SYNC-CHECK: public.add_member_to_organization(p_org_id UUID, p_user_id UUID, p_role_id UUID)
// SYNC-CHECK: public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
// SYNC-CHECK: public.transfer_super_admin(p_org_id UUID, p_new_super_admin_user_id UUID)

import { z } from 'zod';

export const createOrganizationInputSchema = z.object({
  p_name: z.string().min(1, 'Organization name is required').trim(),
  p_description: z.string().optional(),
});
export const createOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  created_at: z.coerce.date(),
});

export const getOrganizationInputSchema = z.object({
  p_id: z.string().uuid(),
});
export const getOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  created_by: z.string().uuid(),
  updated_by: z.string().uuid().nullable(),
  is_deleted: z.boolean(),
  deleted_at: z.coerce.date().nullable(),
  deleted_by: z.string().uuid().nullable(),
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
}).nullable();

export const listMyOrganizationsItemSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  role: z.string(),
});
export const listMyOrganizationsOutputSchema = z.array(listMyOrganizationsItemSchema);

export const updateOrganizationInputSchema = z.object({
  p_id: z.string().uuid(),
  p_name: z.string().min(1).trim(),
  p_description: z.string().optional(),
});
export const updateOrganizationOutputSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  updated_at: z.coerce.date(),
});

export const listOrganizationMembersInputSchema = z.object({
  p_id: z.string().uuid(),
});
export const organizationMemberSchema = z.object({
  user_id: z.string().uuid(),
  email: z.string().email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  role: z.string(),
  is_super_admin: z.boolean(),
});
export const listOrganizationMembersOutputSchema = z.array(organizationMemberSchema);

export const addMemberInputSchema = z.object({
  p_org_id: z.string().uuid(),
  p_user_id: z.string().uuid(),
  p_role_id: z.string().uuid(),
});

export const transferSuperAdminInputSchema = z.object({
  p_org_id: z.string().uuid(),
  p_new_super_admin_user_id: z.string().uuid(),
});

export type CreateOrganizationInput = z.infer<typeof createOrganizationInputSchema>;
export type CreateOrganizationOutput = z.infer<typeof createOrganizationOutputSchema>;
export type ListMyOrganizationsItem = z.infer<typeof listMyOrganizationsItemSchema>;
export type OrganizationMember = z.infer<typeof organizationMemberSchema>;
