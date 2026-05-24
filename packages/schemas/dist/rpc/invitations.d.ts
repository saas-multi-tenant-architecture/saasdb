import { z } from 'zod';
export declare const invitationStatusSchema: z.ZodEnum<{
    pending: "pending";
    accepted: "accepted";
    expired: "expired";
    cancelled: "cancelled";
}>;
export declare const createInvitationInputSchema: z.ZodObject<{
    email: z.ZodPipe<z.ZodString, z.ZodTransform<string, string>>;
    organization_id: z.ZodString;
    role_id: z.ZodString;
    unit_id: z.ZodOptional<z.ZodString>;
    metadata: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
}, z.core.$strip>;
export declare const invitationResponseSchema: z.ZodObject<{
    id: z.ZodString;
    token: z.ZodString;
    email: z.ZodString;
    expires_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>;
export declare const acceptInvitationInputSchema: z.ZodObject<{
    token: z.ZodString;
}, z.core.$strip>;
export declare const invitationDetailsSchema: z.ZodObject<{
    id: z.ZodString;
    email: z.ZodString;
    organization_name: z.ZodString;
    unit_name: z.ZodNullable<z.ZodString>;
    role_name: z.ZodString;
    invited_by_name: z.ZodString;
    expires_at: z.ZodCoercedDate<unknown>;
    status: z.ZodEnum<{
        pending: "pending";
        accepted: "accepted";
        expired: "expired";
        cancelled: "cancelled";
    }>;
}, z.core.$strip>;
export declare const invitationListItemSchema: z.ZodObject<{
    id: z.ZodString;
    email: z.ZodString;
    organization_id: z.ZodString;
    unit_id: z.ZodNullable<z.ZodString>;
    role_name: z.ZodString;
    invited_by_email: z.ZodString;
    status: z.ZodEnum<{
        pending: "pending";
        accepted: "accepted";
        expired: "expired";
        cancelled: "cancelled";
    }>;
    expires_at: z.ZodCoercedDate<unknown>;
    created_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>;
export type InvitationStatus = z.infer<typeof invitationStatusSchema>;
export type CreateInvitationInput = z.infer<typeof createInvitationInputSchema>;
export type InvitationResponse = z.infer<typeof invitationResponseSchema>;
export type InvitationDetails = z.infer<typeof invitationDetailsSchema>;
export type InvitationListItem = z.infer<typeof invitationListItemSchema>;
