"use strict";
// SYNC-CHECK: public.create_organization(p_name TEXT, p_description TEXT DEFAULT NULL)
// SYNC-CHECK: public.get_organization(p_id UUID)
// SYNC-CHECK: public.list_my_organizations()
// SYNC-CHECK: public.update_organization(p_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.list_organization_members(p_id UUID)
// SYNC-CHECK: public.add_member_to_organization(p_org_id UUID, p_user_id UUID, p_role_id UUID)
// SYNC-CHECK: public.remove_user_from_organization(p_user_id UUID, p_org_id UUID)
// SYNC-CHECK: public.transfer_super_admin(p_org_id UUID, p_new_super_admin_user_id UUID)
Object.defineProperty(exports, "__esModule", { value: true });
exports.transferSuperAdminInputSchema = exports.addMemberInputSchema = exports.listOrganizationMembersOutputSchema = exports.organizationMemberSchema = exports.listOrganizationMembersInputSchema = exports.updateOrganizationOutputSchema = exports.updateOrganizationInputSchema = exports.listMyOrganizationsOutputSchema = exports.listMyOrganizationsItemSchema = exports.getOrganizationOutputSchema = exports.getOrganizationInputSchema = exports.createOrganizationOutputSchema = exports.createOrganizationInputSchema = void 0;
const zod_1 = require("zod");
exports.createOrganizationInputSchema = zod_1.z.object({
    p_name: zod_1.z.string().min(1, 'Organization name is required').trim(),
    p_description: zod_1.z.string().optional(),
});
exports.createOrganizationOutputSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    name: zod_1.z.string(),
    created_at: zod_1.z.coerce.date(),
});
exports.getOrganizationInputSchema = zod_1.z.object({
    p_id: zod_1.z.string().uuid(),
});
exports.getOrganizationOutputSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    name: zod_1.z.string(),
    description: zod_1.z.string().nullable(),
    created_by: zod_1.z.string().uuid(),
    updated_by: zod_1.z.string().uuid().nullable(),
    is_deleted: zod_1.z.boolean(),
    deleted_at: zod_1.z.coerce.date().nullable(),
    deleted_by: zod_1.z.string().uuid().nullable(),
    created_at: zod_1.z.coerce.date(),
    updated_at: zod_1.z.coerce.date(),
}).nullable();
exports.listMyOrganizationsItemSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    name: zod_1.z.string(),
    description: zod_1.z.string().nullable(),
    role: zod_1.z.string(),
});
exports.listMyOrganizationsOutputSchema = zod_1.z.array(exports.listMyOrganizationsItemSchema);
exports.updateOrganizationInputSchema = zod_1.z.object({
    p_id: zod_1.z.string().uuid(),
    p_name: zod_1.z.string().min(1).trim(),
    p_description: zod_1.z.string().optional(),
});
exports.updateOrganizationOutputSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    name: zod_1.z.string(),
    description: zod_1.z.string().nullable(),
    updated_at: zod_1.z.coerce.date(),
});
exports.listOrganizationMembersInputSchema = zod_1.z.object({
    p_id: zod_1.z.string().uuid(),
});
exports.organizationMemberSchema = zod_1.z.object({
    user_id: zod_1.z.string().uuid(),
    email: zod_1.z.string().email(),
    first_name: zod_1.z.string().nullable(),
    last_name: zod_1.z.string().nullable(),
    role: zod_1.z.string(),
    is_super_admin: zod_1.z.boolean(),
});
exports.listOrganizationMembersOutputSchema = zod_1.z.array(exports.organizationMemberSchema);
exports.addMemberInputSchema = zod_1.z.object({
    p_org_id: zod_1.z.string().uuid(),
    p_user_id: zod_1.z.string().uuid(),
    p_role_id: zod_1.z.string().uuid(),
});
exports.transferSuperAdminInputSchema = zod_1.z.object({
    p_org_id: zod_1.z.string().uuid(),
    p_new_super_admin_user_id: zod_1.z.string().uuid(),
});
