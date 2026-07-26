// SYNC-CHECK: public.create_invitation(p_email TEXT, p_organization_id UUID, p_role_id UUID, p_unit_id UUID, p_metadata JSONB)
// SYNC-CHECK: public.accept_invitation(p_token TEXT)
// SYNC-CHECK: public.cancel_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.resend_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.list_invitations(p_organization_id UUID, p_status TEXT)
// SYNC-CHECK: public.get_invitation_details(p_token TEXT)

import { z } from 'zod';

export const invitationStatusSchema = z.enum(['pending', 'accepted', 'expired', 'cancelled']);

export const createInvitationInputSchema = z.object({
  email: z.email().transform((email) => email.toLowerCase()),
  organization_id: z.uuid(),
  role_id: z.uuid(),
  unit_id: z.uuid().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

export const invitationResponseSchema = z.object({
  id: z.uuid(),
  token: z.string(),
  email: z.email(),
  expires_at: z.coerce.date(),
});

export const acceptInvitationInputSchema = z.object({
  token: z.string().min(1, 'Invitation token is required'),
});

export const cancelInvitationInputSchema = z.object({
  invitation_id: z.uuid(),
});
// public.cancel_invitation returns void, so it has no output schema. The
// better-auth adapter normalizes that void row to { success: true } at the HTTP
// layer — an adapter contract rather than a public.* RPC contract, so it does
// not belong in this package.

export const resendInvitationInputSchema = z.object({
  invitation_id: z.uuid(),
});

// public.resend_invitation mints a FRESH token so the caller can re-send the
// invitation email, and returns exactly create_invitation's shape. Aliased
// rather than redeclared so the two cannot drift apart.
//
// Unlike list_invitations — which deliberately never re-exposes tokens — a value
// parsed by this schema carries a secret. Do not log or persist it.
export const resendInvitationResponseSchema = invitationResponseSchema;

export const invitationDetailsSchema = z.object({
  id: z.uuid(),
  email: z.email(),
  organization_name: z.string(),
  unit_name: z.string().nullable(),
  role_name: z.string(),
  // core.roles.description. Nullable: roles are seeded per deployment, so a
  // deployment may give a role no label. Required (not .optional()) — all
  // @smta/* packages share one Changesets fixed group and always publish at
  // the same version, so a missing key means the SQL was never applied. That
  // should raise at the first call, not render as a blank label in production.
  role_label: z.string().nullable(),
  invited_by_name: z.string(),
  expires_at: z.coerce.date(),
  status: invitationStatusSchema,
});

export const invitationListItemSchema = z.object({
  id: z.uuid(),
  email: z.email(),
  organization_id: z.uuid(),
  unit_id: z.uuid().nullable(),
  role_name: z.string(),
  role_label: z.string().nullable(),
  invited_by_email: z.email(),
  status: invitationStatusSchema,
  expires_at: z.coerce.date(),
  created_at: z.coerce.date(),
});

export type InvitationStatus = z.infer<typeof invitationStatusSchema>;
export type CreateInvitationInput = z.infer<typeof createInvitationInputSchema>;
export type InvitationResponse = z.infer<typeof invitationResponseSchema>;
export type CancelInvitationInput = z.infer<typeof cancelInvitationInputSchema>;
export type ResendInvitationInput = z.infer<typeof resendInvitationInputSchema>;
export type ResendInvitationResponse = z.infer<typeof resendInvitationResponseSchema>;
export type InvitationDetails = z.infer<typeof invitationDetailsSchema>;
export type InvitationListItem = z.infer<typeof invitationListItemSchema>;
