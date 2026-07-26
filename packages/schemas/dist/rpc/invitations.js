"use strict";
// SYNC-CHECK: public.create_invitation(p_email TEXT, p_organization_id UUID, p_role_id UUID, p_unit_id UUID, p_metadata JSONB)
// SYNC-CHECK: public.accept_invitation(p_token TEXT)
// SYNC-CHECK: public.cancel_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.resend_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.list_invitations(p_organization_id UUID, p_status TEXT)
// SYNC-CHECK: public.get_invitation_details(p_token TEXT)
Object.defineProperty(exports, "__esModule", { value: true });
exports.invitationListItemSchema = exports.invitationDetailsSchema = exports.resendInvitationResponseSchema = exports.resendInvitationInputSchema = exports.cancelInvitationInputSchema = exports.acceptInvitationInputSchema = exports.invitationResponseSchema = exports.createInvitationInputSchema = exports.invitationStatusSchema = void 0;
const zod_1 = require("zod");
exports.invitationStatusSchema = zod_1.z.enum(['pending', 'accepted', 'expired', 'cancelled']);
exports.createInvitationInputSchema = zod_1.z.object({
    email: zod_1.z.email().transform((email) => email.toLowerCase()),
    organization_id: zod_1.z.uuid(),
    role_id: zod_1.z.uuid(),
    unit_id: zod_1.z.uuid().optional(),
    metadata: zod_1.z.record(zod_1.z.string(), zod_1.z.unknown()).optional(),
});
exports.invitationResponseSchema = zod_1.z.object({
    id: zod_1.z.uuid(),
    token: zod_1.z.string(),
    email: zod_1.z.email(),
    expires_at: zod_1.z.coerce.date(),
});
exports.acceptInvitationInputSchema = zod_1.z.object({
    token: zod_1.z.string().min(1, 'Invitation token is required'),
});
exports.cancelInvitationInputSchema = zod_1.z.object({
    invitation_id: zod_1.z.uuid(),
});
// public.cancel_invitation returns void, so it has no output schema. The
// better-auth adapter normalizes that void row to { success: true } at the HTTP
// layer — an adapter contract rather than a public.* RPC contract, so it does
// not belong in this package.
exports.resendInvitationInputSchema = zod_1.z.object({
    invitation_id: zod_1.z.uuid(),
});
// public.resend_invitation mints a FRESH token so the caller can re-send the
// invitation email, and returns exactly create_invitation's shape. Aliased
// rather than redeclared so the two cannot drift apart.
//
// Unlike list_invitations — which deliberately never re-exposes tokens — a value
// parsed by this schema carries a secret. Do not log or persist it.
exports.resendInvitationResponseSchema = exports.invitationResponseSchema;
exports.invitationDetailsSchema = zod_1.z.object({
    id: zod_1.z.uuid(),
    email: zod_1.z.email(),
    organization_name: zod_1.z.string(),
    unit_name: zod_1.z.string().nullable(),
    role_name: zod_1.z.string(),
    // core.roles.description. Nullable: roles are seeded per deployment, so a
    // deployment may give a role no label. Required (not .optional()) — all
    // @smta/* packages share one Changesets fixed group and always publish at
    // the same version, so a missing key means the SQL was never applied. That
    // should raise at the first call, not render as a blank label in production.
    role_label: zod_1.z.string().nullable(),
    invited_by_name: zod_1.z.string(),
    expires_at: zod_1.z.coerce.date(),
    status: exports.invitationStatusSchema,
});
exports.invitationListItemSchema = zod_1.z.object({
    id: zod_1.z.uuid(),
    email: zod_1.z.email(),
    organization_id: zod_1.z.uuid(),
    unit_id: zod_1.z.uuid().nullable(),
    role_name: zod_1.z.string(),
    role_label: zod_1.z.string().nullable(),
    invited_by_email: zod_1.z.email(),
    status: exports.invitationStatusSchema,
    expires_at: zod_1.z.coerce.date(),
    created_at: zod_1.z.coerce.date(),
});
