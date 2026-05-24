// SYNC-CHECK: public.create_invitation(p_email TEXT, p_org_id UUID, p_role_id UUID, p_unit_id UUID, p_metadata JSONB)
// SYNC-CHECK: public.accept_invitation(p_token TEXT)
// SYNC-CHECK: public.cancel_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.resend_invitation(p_invitation_id UUID)
// SYNC-CHECK: public.list_invitations(p_org_id UUID, p_status TEXT)
// SYNC-CHECK: public.get_invitation_details(p_token TEXT)

import { z } from 'zod';

export const invitationStatusSchema = z.enum(['pending', 'accepted', 'expired', 'cancelled']);

export const createInvitationInputSchema = z.object({
  email: z.string().email().transform((email) => email.toLowerCase()),
  organization_id: z.string().uuid(),
  role_id: z.string().uuid(),
  unit_id: z.string().uuid().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

export const invitationResponseSchema = z.object({
  id: z.string().uuid(),
  token: z.string(),
  email: z.string().email(),
  expires_at: z.coerce.date(),
});

export const acceptInvitationInputSchema = z.object({
  token: z.string().min(1, 'Invitation token is required'),
});

export const invitationDetailsSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  organization_name: z.string(),
  unit_name: z.string().nullable(),
  role_name: z.string(),
  invited_by_name: z.string(),
  expires_at: z.coerce.date(),
  status: invitationStatusSchema,
});

export const invitationListItemSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  organization_id: z.string().uuid(),
  unit_id: z.string().uuid().nullable(),
  role_name: z.string(),
  invited_by_email: z.string().email(),
  status: invitationStatusSchema,
  expires_at: z.coerce.date(),
  created_at: z.coerce.date(),
});

export type InvitationStatus = z.infer<typeof invitationStatusSchema>;
export type CreateInvitationInput = z.infer<typeof createInvitationInputSchema>;
export type InvitationResponse = z.infer<typeof invitationResponseSchema>;
export type InvitationDetails = z.infer<typeof invitationDetailsSchema>;
export type InvitationListItem = z.infer<typeof invitationListItemSchema>;
