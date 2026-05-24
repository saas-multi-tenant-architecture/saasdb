"use strict";
// SYNC-CHECK: public.create_invitation(p_email TEXT, p_org_id UUID, p_role_id UUID, p_unit_id UUID, p_metadata JSONB)
// SYNC-CHECK: public.accept_invitation(p_token TEXT)
// SYNC-CHECK: public.cancel_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.resend_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.list_invitations(p_org_id UUID, p_status TEXT)
// SYNC-CHECK: public.get_invitation_details(p_token TEXT)
Object.defineProperty(exports, "__esModule", { value: true });
exports.invitationListItemSchema = exports.invitationDetailsSchema = exports.acceptInvitationInputSchema = exports.invitationResponseSchema = exports.createInvitationInputSchema = exports.invitationStatusSchema = void 0;
const zod_1 = require("zod");
exports.invitationStatusSchema = zod_1.z.enum(['pending', 'accepted', 'expired', 'cancelled']);
exports.createInvitationInputSchema = zod_1.z.object({
    email: zod_1.z.string().email().transform((email) => email.toLowerCase()),
    organization_id: zod_1.z.string().uuid(),
    role_id: zod_1.z.string().uuid(),
    unit_id: zod_1.z.string().uuid().optional(),
    metadata: zod_1.z.record(zod_1.z.string(), zod_1.z.unknown()).optional(),
});
exports.invitationResponseSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    token: zod_1.z.string(),
    email: zod_1.z.string().email(),
    expires_at: zod_1.z.coerce.date(),
});
exports.acceptInvitationInputSchema = zod_1.z.object({
    token: zod_1.z.string().min(1, 'Invitation token is required'),
});
exports.invitationDetailsSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    email: zod_1.z.string().email(),
    organization_name: zod_1.z.string(),
    unit_name: zod_1.z.string().nullable(),
    role_name: zod_1.z.string(),
    invited_by_name: zod_1.z.string(),
    expires_at: zod_1.z.coerce.date(),
    status: exports.invitationStatusSchema,
});
exports.invitationListItemSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    email: zod_1.z.string().email(),
    organization_id: zod_1.z.string().uuid(),
    unit_id: zod_1.z.string().uuid().nullable(),
    role_name: zod_1.z.string(),
    invited_by_email: zod_1.z.string().email(),
    status: exports.invitationStatusSchema,
    expires_at: zod_1.z.coerce.date(),
    created_at: zod_1.z.coerce.date(),
});
