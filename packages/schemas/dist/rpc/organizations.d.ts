import { z } from 'zod';
export declare const createOrganizationInputSchema: z.ZodObject<{
    p_name: z.ZodString;
    p_description: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
export declare const createOrganizationOutputSchema: z.ZodObject<{
    id: z.ZodUUID;
    name: z.ZodString;
    created_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>;
export declare const getOrganizationInputSchema: z.ZodObject<{
    p_id: z.ZodUUID;
}, z.core.$strip>;
export declare const getOrganizationOutputSchema: z.ZodNullable<z.ZodObject<{
    id: z.ZodUUID;
    name: z.ZodString;
    description: z.ZodNullable<z.ZodString>;
    created_by: z.ZodUUID;
    updated_by: z.ZodNullable<z.ZodUUID>;
    is_deleted: z.ZodBoolean;
    deleted_at: z.ZodNullable<z.ZodCoercedDate<unknown>>;
    deleted_by: z.ZodNullable<z.ZodUUID>;
    created_at: z.ZodCoercedDate<unknown>;
    updated_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>>;
export declare const listMyOrganizationsItemSchema: z.ZodObject<{
    id: z.ZodUUID;
    name: z.ZodString;
    description: z.ZodNullable<z.ZodString>;
    role: z.ZodString;
}, z.core.$strip>;
export declare const listMyOrganizationsOutputSchema: z.ZodArray<z.ZodObject<{
    id: z.ZodUUID;
    name: z.ZodString;
    description: z.ZodNullable<z.ZodString>;
    role: z.ZodString;
}, z.core.$strip>>;
export declare const updateOrganizationInputSchema: z.ZodObject<{
    p_id: z.ZodUUID;
    p_name: z.ZodString;
    p_description: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
export declare const updateOrganizationOutputSchema: z.ZodObject<{
    id: z.ZodUUID;
    name: z.ZodString;
    description: z.ZodNullable<z.ZodString>;
    updated_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>;
export declare const listOrganizationMembersInputSchema: z.ZodObject<{
    p_id: z.ZodUUID;
}, z.core.$strip>;
export declare const organizationMemberSchema: z.ZodObject<{
    user_id: z.ZodUUID;
    email: z.ZodEmail;
    first_name: z.ZodNullable<z.ZodString>;
    last_name: z.ZodNullable<z.ZodString>;
    role: z.ZodString;
    is_super_admin: z.ZodBoolean;
}, z.core.$strip>;
export declare const listOrganizationMembersOutputSchema: z.ZodArray<z.ZodObject<{
    user_id: z.ZodUUID;
    email: z.ZodEmail;
    first_name: z.ZodNullable<z.ZodString>;
    last_name: z.ZodNullable<z.ZodString>;
    role: z.ZodString;
    is_super_admin: z.ZodBoolean;
}, z.core.$strip>>;
export declare const addMemberInputSchema: z.ZodObject<{
    p_org_id: z.ZodUUID;
    p_user_id: z.ZodUUID;
    p_role_id: z.ZodUUID;
}, z.core.$strip>;
export declare const transferSuperAdminInputSchema: z.ZodObject<{
    p_org_id: z.ZodUUID;
    p_new_super_admin_user_id: z.ZodUUID;
}, z.core.$strip>;
export type CreateOrganizationInput = z.infer<typeof createOrganizationInputSchema>;
export type CreateOrganizationOutput = z.infer<typeof createOrganizationOutputSchema>;
export type ListMyOrganizationsItem = z.infer<typeof listMyOrganizationsItemSchema>;
export type OrganizationMember = z.infer<typeof organizationMemberSchema>;
