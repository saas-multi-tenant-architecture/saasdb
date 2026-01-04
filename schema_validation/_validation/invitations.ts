import {
  invitationsSchema,
  createInvitationInputSchema,
  acceptInvitationInputSchema,
  invitationDetailsSchema,
  invitationListItemSchema,
} from '../_schemas/invitations';
import {
  Invitation,
  CreateInvitationInput,
  AcceptInvitationInput,
  InvitationDetails,
  InvitationListItem,
} from '../_types';

export function validateInvitation(data: unknown): { success: true; data: Invitation } | { success: false; error: any } {
  const result = invitationsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

export function validateCreateInvitationInput(data: unknown): { success: true; data: CreateInvitationInput } | { success: false; error: any } {
  const result = createInvitationInputSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

export function validateAcceptInvitationInput(data: unknown): { success: true; data: AcceptInvitationInput } | { success: false; error: any } {
  const result = acceptInvitationInputSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

export function validateInvitationDetails(data: unknown): { success: true; data: InvitationDetails } | { success: false; error: any } {
  const result = invitationDetailsSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

export function validateInvitationListItem(data: unknown): { success: true; data: InvitationListItem } | { success: false; error: any } {
  const result = invitationListItemSchema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}
